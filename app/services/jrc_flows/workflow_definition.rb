class JrcFlows::WorkflowDefinition
  TYPES = %w[webhook executeWorkflowTrigger code if switch redis respondToWebhook executeWorkflow httpRequest set noOp stickyNote].freeze
  AI_TYPES = %w[@n8n/n8n-nodes-langchain.agent @n8n/n8n-nodes-langchain.lmChatOpenAi].freeze
  STARTS = %w[n8n-nodes-base.webhook n8n-nodes-base.executeWorkflowTrigger].freeze

  def initialize(flow)
    @flow = flow
    @workflow = flow.source_definition || {}
  end

  def errors(complete: true)
    return ['Configurações inválidas.'] unless @flow.settings.is_a?(Hash) && @flow.settings['inbox_ids'].is_a?(Array)
    nodes, connections = @workflow.values_at('nodes', 'connections')
    return ['Workflow inválido: informe nodes e connections.'] unless nodes.is_a?(Array) && connections.is_a?(Hash)
    return ['Limite de 150 nós e 2 MB por workflow.'] if nodes.size > 150 || @workflow.to_json.bytesize > 2.megabytes
    return ['Nó inválido.'] unless nodes.all? { |n| n.is_a?(Hash) && n['name'].is_a?(String) && n['type'].is_a?(String) && n['parameters'].is_a?(Hash) }

    errors = []
    names = nodes.pluck('name')
    errors << 'Use nomes e IDs únicos nos nós.' if names.uniq.size != nodes.size || nodes.pluck('id').uniq.size != nodes.size
    connections.each do |name, groups|
      return ['Formato de conexões inválido.'] unless names.include?(name) && groups.is_a?(Hash)
      groups.each do |type, ports|
        return ['Conexão inválida.'] unless ports.is_a?(Array) && ports.all? { |port| port.is_a?(Array) && port.all? { |e| e.is_a?(Hash) && names.include?(e['node']) && e['index'] == 0 } }

        errors << "Conexão #{type} ainda não suportada." unless %w[main ai_languageModel].include?(type)
      end
    end
    return errors unless complete

    %w[workflow_team_id workflow_support_team_id workflow_financial_team_id workflow_commercial_team_id].each do |key|
      errors << 'A equipe de transferência deve pertencer à conta.' if @flow.settings[key].present? && !@flow.execution_team_ids.include?(@flow.settings[key].to_i)
    end

    errors << 'O serviço interno de execução JavaScript não está configurado.' if ENV['JRC_FLOWS_SANDBOX_URL'].blank?
    errors << 'O workflow precisa de exatamente uma entrada.' unless nodes.count { |n| STARTS.include?(n['type']) && !n['disabled'] } == 1
    if nodes.any? { |n| n['type'] == '@n8n/n8n-nodes-langchain.agent' } && @flow.settings['workflow_team_id'].blank?
      errors << 'Selecione a equipe padrão para transferências do chatbot.'
    end
    nodes.reject { |node| node['disabled'] }.each do |node|
      type, params = node.values_at('type', 'parameters')
      errors << "#{node['name']}: tipo #{type} ainda não suportado pelo motor JRC." unless TYPES.include?(type.delete_prefix('n8n-nodes-base.')) || AI_TYPES.include?(type)
      errors << "#{node['name']}: apenas JavaScript síncrono, sem módulos, é suportado." if type == 'n8n-nodes-base.code' &&
        (params['language'].present? && params['language'] != 'javaScript' || params['mode'] == 'runOnceForEachItem')
      if type == 'n8n-nodes-base.executeWorkflow'
        child = @flow.sibling_flows.find_by(id: params['jrc_flow_id'])
        errors << "#{node['name']}: importe e selecione o subworkflow JRC correspondente." unless child&.engine == 'workflow' && child.id != @flow.id
      end
      if type == '@n8n/n8n-nodes-langchain.lmChatOpenAi'
        errors << "#{node['name']}: configure a chave OpenAI no JRC." if @flow.effective_secrets['openai_api_key'].blank?
      end
      if type == '@n8n/n8n-nodes-langchain.agent'
        models = connections.select { |_, g| g.fetch('ai_languageModel', []).flatten.any? { |e| e['node'] == node['name'] } }
        errors << "#{node['name']}: conecte exatamente um modelo de IA." unless models.size == 1
      end
      errors << "#{node['name']}: operação Redis não suportada." if type == 'n8n-nodes-base.redis' && %w[get set delete].exclude?(params['operation'])
      errors << "#{node['name']}: use Switch por regras." if type == 'n8n-nodes-base.switch' && !params.dig('rules', 'values').is_a?(Array)
      if %w[n8n-nodes-base.if n8n-nodes-base.switch].include?(type)
        groups = type.end_with?('.if') ? [params['conditions']] : Array(params.dig('rules', 'values')).map { |rule| rule['conditions'] }
        valid = groups.all? do |group|
          group.is_a?(Hash) && group['conditions'].is_a?(Array) && group['conditions'].any? && group['conditions'].all? do |condition|
            condition.is_a?(Hash) && %w[true false equals equal notEquals contains notContains startsWith empty notEmpty exists notExists gt gte lt lte].include?(condition.dig('operator', 'operation'))
          end
        end
        errors << "#{node['name']}: formato ou operador de condição ainda não suportado." unless valid
      end
      if type == 'n8n-nodes-base.httpRequest' && params['authentication'].present? && params['authentication'] != 'none' && !params['jrc_use_credential']
        errors << "#{node['name']}: mapeie a autenticação para a credencial HTTP do JRC."
      end
      if type == 'n8n-nodes-base.httpRequest' && params['jrc_use_credential'] && @flow.effective_secrets['http_api_key'].blank?
        errors << "#{node['name']}: configure a credencial HTTP no JRC."
      end
      if node['retryOnFail'] || node['onError'].present? && %w[stopWorkflow continueRegularOutput].exclude?(node['onError'])
        errors << "#{node['name']}: tentativas automáticas e saída separada de erro ainda não são suportadas."
      end
    end
    errors.uniq
  end
end
