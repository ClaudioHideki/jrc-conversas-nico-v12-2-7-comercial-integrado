class JrcFlows::Definition
  TYPES = %w[start message media input switch condition delay note assign labels status variable contact webhook create_lead move_deal activity nico end].freeze
  TRIGGERS = %w[message_created conversation_created conversation_opened conversation_resolved label_added stage_changed schedule manual].freeze
  OPERATORS = %w[equals contains starts_with not_equals present].freeze
  TERMINAL = %w[end assign nico].freeze

  def initialize(flow)
    @flow = flow
  end

  def errors(complete: true)
    @errors = []
    if @flow.respond_to?(:engine) && @flow.engine == 'workflow'
      @errors = JrcFlows::WorkflowDefinition.new(@flow).errors(complete: complete)
      validate_settings if complete
      return @errors
    end
    graph = @flow.graph
    return ['O fluxo deve conter blocos e conexões.'] unless graph.is_a?(Hash) && graph['nodes'].is_a?(Array) && graph['edges'].is_a?(Array)
    @nodes, @edges = graph.values_at('nodes', 'edges')
    return ['Limite de 150 blocos e 300 conexões por fluxo.'] if @nodes.size > 150 || @edges.size > 300 || graph.to_json.bytesize > 250_000
    return ['Formato de bloco ou conexão inválido.'] unless @nodes.all? { |n| n.is_a?(Hash) && n['data'].is_a?(Hash) } && @edges.all? { |e| e.is_a?(Hash) }

    return ['Configurações inválidas.'] unless @flow.settings.is_a?(Hash)
    return ['Identificador, nome ou posição de bloco inválidos.'] unless @nodes.all? do |node|
      node['id'].is_a?(String) && node['id'].size <= 80 && node['label'].is_a?(String) && node['label'].size <= 120 &&
        node['position'].is_a?(Hash) && %w[x y].all? { |key| node['position'][key].is_a?(Numeric) && (0..100_000).cover?(node['position'][key]) }
    end
    return ['Opções do switch inválidas.'] if @nodes.any? { |n| n['type'] == 'switch' && (!n.dig('data', 'cases').is_a?(Array) || n['data']['cases'].any? { |c| !c.is_a?(Hash) }) }
    return ['Conexão inválida.'] unless @edges.all? { |e| %w[id source target port].all? { |key| e[key].is_a?(String) && e[key].size <= 100 } }
    return ['Caixas e dias devem ser listas.'] unless @flow.settings['inbox_ids'].is_a?(Array) && @flow.settings['days'].is_a?(Array)

    scalar = ->(value) { value.nil? || value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false }
    return ['Valor de bloco inválido. Use texto, número ou as listas do editor.'] unless @nodes.all? do |node|
      node['data'].all? do |key, value|
        if %w[labels allowed_actions].include?(key)
          value.is_a?(Array) && value.all? { |item| item.is_a?(String) }
        elsif key == 'cases'
          value.is_a?(Array) && value.all? do |item|
            item.is_a?(Hash) && %w[id label operator value].all? { |field| item[field].is_a?(String) }
          end
        else
          scalar.call(value) && value != true && value != false
        end
      end
    end
    return ['Configurações possuem valores inválidos.'] unless @flow.settings.all? do |key, value|
      %w[inbox_ids days conversation_ids].include?(key) ? value.is_a?(Array) && value.all? { |id| id.is_a?(Integer) } : scalar.call(value)
    end
    return ['Nome de gatilho ou palavra-chave inválidos.'] if %w[trigger keyword label timezone opens_at closes_at].any? do |key|
      @flow.settings.key?(key) && !@flow.settings[key].is_a?(String)
    end

    return ['Etapa e intervalo devem ser numéricos.'] if %w[stage_id interval_minutes].any? do |key|
      value = @flow.settings[key]
      !value.nil? && !value.is_a?(String) && !value.is_a?(Numeric)
    end

    ids = @nodes.pluck('id')
    @errors << 'Os blocos precisam ter identificadores únicos.' if ids.any?(&:blank?) || ids.uniq.size != ids.size
    @errors << 'Há um tipo de bloco desconhecido.' if @nodes.any? { |node| TYPES.exclude?(node['type']) }
    @errors << 'O fluxo precisa de exatamente um início.' unless @nodes.count { |n| n['type'] == 'start' } == 1
    @errors << 'Uma conexão aponta para um bloco inexistente.' if @edges.any? { |e| !ids.include?(e['source']) || !ids.include?(e['target']) }
    @errors << 'Cada saída permite uma única conexão.' if @edges.map { |e| [e['source'], e['port']] }.uniq.size != @edges.size
    @edges.each do |edge|
      source = @nodes.find { |node| node['id'] == edge['source'] }
      @errors << 'Saída de conexão inválida.' if source && ports(source).exclude?(edge['port'])
      @errors << 'Não conecte ao bloco de início.' if @nodes.any? { |n| n['id'] == edge['target'] && n['type'] == 'start' }
    end
    return @errors unless complete

    @errors << 'Voz em tempo real requer um adaptador de telefonia e ainda não pode ser ativada.' if @flow.kind == 'voice'
    validate_settings
    @nodes.each { |node| validate_node(node) }
    validate_paths if @errors.empty?
    @errors.uniq
  end

  def path_errors
    structural = errors(complete: false)
    return structural if structural.any?
    validate_paths
    @errors.uniq
  end

  def ports(node)
    case node['type']
    when *TERMINAL then []
    when 'switch' then Array(node.dig('data', 'cases')).filter_map { |item| item['id'] if item.is_a?(Hash) } + ['fallback']
    when 'condition' then %w[yes no]
    when 'input' then %w[next timeout]
    else ['next']
    end
  end

  private

  def validate_settings
    settings = @flow.settings
    unless settings.is_a?(Hash) && TRIGGERS.include?(settings['trigger'])
      @errors << 'Selecione um gatilho válido.'
      return
    end
    inbox_ids = Array(settings['inbox_ids']).map(&:to_i)
    @errors << 'Selecione ao menos uma caixa de entrada.' if inbox_ids.empty?
    @errors << 'Uma caixa não pertence à conta.' unless (@flow.account.inboxes.ids & inbox_ids).sort == inbox_ids.uniq.sort
    @errors << 'Chatbots iniciam por mensagem recebida.' if @flow.kind == 'chatbot' && settings['trigger'] != 'message_created'
    @errors << 'Informe a etiqueta do gatilho.' if settings['trigger'] == 'label_added' && settings['label'].blank?
    if settings['trigger'] == 'stage_changed'
      @errors << 'Habilite o CRM e selecione uma etapa válida.' unless @flow.account.feature_enabled?('jrc_crm') &&
        JrcCrm::Stage.where(account: @flow.account, active: true).exists?(settings['stage_id'])
    end
    if settings['trigger'] == 'schedule'
      ids = settings['conversation_ids']
      valid_ids = ids.is_a?(Array) && ids.size.between?(1, 100) && ids.all? { |id| id.is_a?(Integer) && id.positive? }
      @errors << 'Selecione de 1 a 100 números de conversas para a recorrência.' unless valid_ids
      @errors << 'Intervalo recorrente deve ficar entre 1 minuto e 7 dias.' unless (1..10_080).cover?(settings['interval_minutes'].to_i)
      if valid_ids && @flow.account.conversations.where(display_id: ids, inbox_id: inbox_ids).count != ids.uniq.size
        @errors << 'As conversas recorrentes devem pertencer às caixas selecionadas nesta conta.'
      end
    end
    if settings['business_hours'] == true
      @errors << 'Fuso horário inválido.' unless ActiveSupport::TimeZone[settings['timezone']]
      @errors << 'Informe os horários no formato HH:MM.' unless %w[opens_at closes_at].all? { |key| settings[key].to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/) }
      @errors << 'Selecione os dias de atendimento (0 a 6).' unless Array(settings['days']).any? && Array(settings['days']).all? { |day| (0..6).include?(day) }
    end
  end

  def validate_node(node)
    data = node['data']
    required = {
      'message' => %w[text], 'media' => %w[url], 'input' => %w[variable], 'condition' => %w[field operator],
      'note' => %w[text], 'status' => %w[status], 'variable' => %w[variable value], 'contact' => %w[field value],
      'webhook' => %w[url], 'activity' => %w[title user_id], 'nico' => %w[objective], 'move_deal' => %w[stage_id]
    }.fetch(node['type'], [])
    required.each { |key| @errors << "#{node['label']}: preencha #{key}." if data[key].blank? }
    if %w[condition switch].include?(node['type'])
      cases = node['type'] == 'switch' ? Array(data['cases']) : [data]
      @errors << 'Switch precisa de 1 a 10 opções válidas e únicas.' if node['type'] == 'switch' &&
        (cases.empty? || cases.size > 10 || cases.any? { |c| !c.is_a?(Hash) || c['id'].blank? || c['value'].blank? } ||
         cases.filter_map { |c| c['id'] if c.is_a?(Hash) }.uniq.size != cases.size)
      @errors << 'Operador de condição inválido.' if cases.any? { |item| !item.is_a?(Hash) || OPERATORS.exclude?(item['operator']) }
    end
    @errors << 'Informe uma variável válida.' if %w[input variable].include?(node['type']) && !data['variable'].to_s.match?(/\A[a-zA-Z_][a-zA-Z0-9_]{0,63}\z/)
    @errors << 'Informe uma espera entre 1 segundo e 7 dias.' if node['type'] == 'delay' && !(1..604_800).cover?(data['seconds'].to_i)
    @errors << 'Informe um prazo de resposta entre 1 segundo e 7 dias.' if node['type'] == 'input' && !(1..604_800).cover?(data['timeout'].to_i)
    @errors << 'Status de conversa inválido.' if node['type'] == 'status' && %w[open pending resolved].exclude?(data['status'])
    @errors << 'Campo de contato inválido.' if node['type'] == 'contact' && %w[name email phone_number].exclude?(data['field'])
    @errors << 'Informe as etiquetas.' if node['type'] == 'labels' && Array(data['labels']).reject(&:blank?).empty?
    if node['type'] == 'assign'
      @errors << 'Selecione um atendente ou equipe.' if data['agent_id'].blank? && data['team_id'].blank?
      @errors << 'Atendente inválido.' if data['agent_id'].present? && !@flow.account.users.exists?(data['agent_id'])
      @errors << 'Equipe inválida.' if data['team_id'].present? && !@flow.account.teams.exists?(data['team_id'])
    end
    @errors << 'CRM não está habilitado nesta conta.' if %w[create_lead move_deal activity].include?(node['type']) && !@flow.account.feature_enabled?('jrc_crm')
    if node['type'] == 'labels'
      unknown = Array(data['labels']) - @flow.account.labels.pluck(:title)
      @errors << 'Selecione etiquetas existentes nesta conta.' if unknown.any?
    end
    if node['type'] == 'activity'
      @errors << 'Responsável inválido.' unless @flow.account.users.exists?(data['user_id'])
    end
    if node['type'] == 'move_deal'
      @errors << 'Etapa inválida.' unless JrcCrm::Stage.where(account: @flow.account, active: true).exists?(data['stage_id'])
    end
    if node['type'] == 'nico'
      @errors << 'Permissões do Nico inválidas.' unless data['allowed_actions'].is_a?(Array) && (data['allowed_actions'] - JrcNico::DelegatedActions::GROUPS.keys).empty?
    end
    if node['type'] == 'nico' && (@flow.account.custom_attributes['nico_enabled'] != true || ENV['NICO_MODE'] != 'provider')
      @errors << 'Habilite o Nico e configure seu provedor antes de ativar este fluxo.'
    end
    if %w[webhook media].include?(node['type'])
      uri = URI.parse(data['url'].to_s)
      @errors << 'Use uma URL HTTPS pública, sem credenciais ou variáveis no endereço.' unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && !data['url'].to_s.include?('{{')
    end
    return if TERMINAL.include?(node['type'])

    ports(node).each { |port| @errors << "#{node['label']}: conecte a saída #{port}." unless @edges.any? { |e| e['source'] == node['id'] && e['port'] == port } }
  rescue URI::InvalidURIError
    @errors << 'URL inválida.'
  end

  def validate_paths
    visited, visiting = [], []
    walk = lambda do |id|
      if visiting.include?(id)
        @errors << 'Remova o ciclo entre blocos. Use a espera por resposta para continuar a conversa.'
        return
      end
      return if visited.include?(id)

      visiting << id
      @edges.select { |e| e['source'] == id }.each { |e| walk.call(e['target']) }
      visiting.delete(id)
      visited << id
    end
    walk.call(@nodes.find { |n| n['type'] == 'start' }['id'])
    @errors << 'Existem blocos desconectados do início.' unless visited.size == @nodes.size
  end
end
