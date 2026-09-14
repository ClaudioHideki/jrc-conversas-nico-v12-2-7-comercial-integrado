class JrcNico::AutomationActions
  TOOLS = {
    'list_automations' => ['Consultar regras persistentes de atendimento, incluindo condições, ações e estado', 'automations', false, []],
    'create_automation' => ['Criar regra persistente desativada para revisão. Evento conversation_created/conversation_updated/message_created; filtre por caixa e conteúdo. Ações: etiqueta, equipe ou mensagem. Não agenda recorrência diária.',
                            'automations', true, %w[name* event_name* inbox_id* content_contains label team_id message_body]],
    'activate_automation' => ['Ativar uma regra de atendimento revisada pelo operador', 'automations', true, %w[automation_id*]],
    'pause_automation' => ['Pausar uma regra persistente de atendimento', 'automations', true, %w[automation_id*]]
  }.freeze
  EVENTS = %w[conversation_created conversation_updated message_created].freeze

  def initialize(access)
    @access = access.authorize!
    @account = access.account
    raise Pundit::NotAuthorizedError unless @account.feature_enabled?('automations') && @access.policy(AutomationRule).create?
  end

  def call(name, args)
    case name
    when 'list_automations'
      @account.automation_rules.order(:id).map { |rule| rule.slice(:id, :name, :event_name, :active, :conditions, :actions) }
    when 'create_automation'
      create(args)
    when 'activate_automation', 'pause_automation'
      rule = @account.automation_rules.find(args.fetch('automation_id'))
      raise Pundit::NotAuthorizedError unless @access.policy(rule).update?

      rule.update!(active: name == 'activate_automation')
      receipt(rule, rule.active? ? 'Regra ativada' : 'Regra pausada')
    else
      raise ArgumentError, 'Ação de automação desconhecida.'
    end
  end

  private

  def create(args)
    raise ArgumentError, 'Evento de automação inválido.' unless EVENTS.include?(args['event_name'])

    inbox = @account.inboxes.find(args.fetch('inbox_id'))
    raise Pundit::NotAuthorizedError unless @access.inbox_visible?(inbox)

    conditions = [{ attribute_key: 'inbox_id', filter_operator: 'equal_to', values: [inbox.id], query_operator: nil }]
    if args['content_contains'].present?
      raise ArgumentError, 'Filtro de conteúdo requer message_created.' unless args['event_name'] == 'message_created'

      conditions << { attribute_key: 'content', filter_operator: 'contains', values: [args['content_contains']], query_operator: nil }
    end
    # Outgoing replies must not retrigger an automatic reply.
    if args['event_name'] == 'message_created'
      conditions << { attribute_key: 'message_type', filter_operator: 'equal_to', values: ['incoming'], query_operator: nil }
    end
    conditions[0...-1].each { |condition| condition[:query_operator] = 'AND' }
    actions = []
    if args['label'].present?
      label = @account.labels.find_by!(title: args['label'])
      actions << { action_name: 'add_label', action_params: [label.title] }
    end
    if args['team_id']
      team = @account.teams.find(args['team_id'])
      actions << { action_name: 'assign_team', action_params: [team.id] }
    end
    if args['message_body'].present?
      raise ArgumentError, 'Resposta automática requer message_created e filtro de conteúdo.' unless args['event_name'] == 'message_created' && args['content_contains'].present?

      actions << { action_name: 'send_message', action_params: [args['message_body']] }
    end
    raise ArgumentError, 'Informe etiqueta, equipe ou mensagem para a regra.' if actions.empty?

    rule = @account.automation_rules.new(name: args['name'], event_name: args['event_name'], active: false,
                                         conditions: conditions.as_json, actions: actions.as_json)
    raise ArgumentError, 'Condições inválidas.' unless AutomationRules::ConditionValidationService.new(rule).perform

    rule.save!
    receipt(rule, 'Regra criada desativada; revise antes de ativar')
  end

  def receipt(rule, message)
    { message: "#{message}: #{rule.name} (##{rule.id})", resource_type: 'AutomationRule',
      record: rule.slice(:id, :name, :active, :event_name, :conditions, :actions), route_name: 'automation_list' }
  end
end
