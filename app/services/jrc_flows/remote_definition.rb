class JrcFlows::RemoteDefinition
  NATIVE_TYPES = %w[start message input switch condition delay note assign labels status variable end].freeze

  def initialize(flow)
    @flow = flow
    @connection = flow.connection
  end

  def errors(complete: true)
    errors = if @flow.engine == 'workflow'
               JrcFlows::WorkflowDefinition.new(@flow).errors(complete: complete)
             else
               JrcFlows::Definition.new(@flow).errors(complete: false)
             end
    return errors if !complete || errors.any?

    errors << 'Teste e instale a conexão Chatwoot antes de ativar.' unless @connection&.enabled? && @connection.verified_at
    inbox_ids = Array(@flow.settings['inbox_ids'])
    errors << 'Selecione caixas autorizadas nesta conexão.' if inbox_ids.empty? || (inbox_ids - @connection.inbox_ids).any?
    errors << 'O conector remoto inicia por mensagem recebida.' unless @flow.settings['trigger'] == 'message_created'
    errors << 'Voz ainda não está disponível no conector.' if @flow.kind == 'voice'
    errors << 'Horário restrito ainda não está disponível no conector remoto.' if @flow.settings['business_hours'] == true
    errors << 'A pausa para atendimento humano é obrigatória no conector remoto.' if @flow.settings['pause_on_agent'] == false
    if @flow.engine == 'native'
      validator = JrcFlows::Definition.new(@flow)
      errors.concat(validator.path_errors)
      @flow.graph['nodes'].each do |node|
        type, data = node.values_at('type', 'data')
        errors << "#{node['label']}: bloco #{type} indisponível nesta conexão Chatwoot." unless NATIVE_TYPES.include?(type)
        errors << "#{node['label']}: informe o texto." if %w[message note].include?(type) && data['text'].blank?
        errors << "#{node['label']}: variável inválida." if %w[input variable].include?(type) && !data['variable'].to_s.match?(/\A[a-zA-Z_][a-zA-Z0-9_]{0,63}\z/)
        if type == 'input' || type == 'delay'
          key = type == 'input' ? 'timeout' : 'seconds'
          errors << "#{node['label']}: prazo deve ser entre 1 segundo e 7 dias." unless (1..604_800).cover?(data[key].to_i)
        end
        errors << 'Status inválido.' if type == 'status' && %w[open pending resolved].exclude?(data['status'])
        if type == 'assign'
          errors << 'Selecione a equipe ou atendente de destino.' if data['agent_id'].blank? && data['team_id'].blank?
          errors << 'Equipe inválida nesta conexão.' if data['team_id'].present? && !@flow.execution_team_ids.include?(data['team_id'].to_i)
          errors << 'Atendente inválido nesta conexão.' if data['agent_id'].present? && !@connection.catalog.fetch('agents', []).pluck('id').include?(data['agent_id'].to_i)
        end
        errors << 'Etiquetas não pertencem à conexão.' if type == 'labels' && (Array(data['labels']) - @connection.catalog.fetch('labels', [])).any?
        rules = type == 'switch' ? Array(data['cases']) : type == 'condition' ? [data] : []
        errors << 'Operador inválido.' if rules.any? { |rule| JrcFlows::Definition::OPERATORS.exclude?(rule['operator']) }
        validator.ports(node).each do |port|
          errors << "#{node['label']}: conecte a saída #{port}." unless @flow.graph['edges'].any? { |edge| edge['source'] == node['id'] && edge['port'] == port }
        end
      end
    end
    errors.uniq
  end
end
