class JrcNico::DelegatedActions
  GROUPS = {
    'contacts' => %w[update_contact],
    'leads' => %w[create_lead],
    'proposals' => %w[create_lead convert_lead create_deal create_proposal update_proposal add_proposal_item],
    'meetings' => %w[create_lead create_activity],
    'calls' => %w[call_contact]
  }.freeze

  def self.for_notice(notice)
    return unless notice && notice.metadata['delegation_id'] && notice.metadata['delegation_version']

    JrcNico::Delegation.find_by(id: notice.metadata['delegation_id'], version: notice.metadata['delegation_version'],
                              account: notice.account, user: notice.user, conversation: notice.conversation)
  end

  def self.permitted?(delegation, command, access)
    return false unless delegation && command.source_notice && delegation.live?
    return false unless delegation.user_id == access.user.id && delegation.account_id == access.account.id
    return false unless delegation.conversation_id == command.source_notice.conversation_id
    return false unless delegation.id == command.source_notice.metadata['delegation_id'] &&
                        delegation.version == command.source_notice.metadata['delegation_version']

    conversation = delegation.conversation.reload
    return false unless conversation.pending? && conversation.assignee_agent_bot_id == delegation.agent_bot_id

    groups = delegation.allowed_actions
    tools = groups.flat_map { |group| GROUPS.fetch(group) }
    tools << 'create_lead' if delegation.allow_crm?
    return false unless tools.include?(command.tool)
    return false unless JrcNico::ToolCatalog.new(access).available.any? { |tool| tool[:name] == command.tool }

    args = command.arguments
    return false if command.tool == 'create_activity' && args['activity_type'] != 'meeting'
    return false if command.tool == 'create_lead' && args['conversation_id'].blank? && args['contact_id'].blank?
    return false if command.tool == 'create_deal' && args['contact_id'] != conversation.contact_id
    return false if command.tool == 'update_proposal' && args.fetch('discount_cents', 0).positive?
    if %w[update_proposal add_proposal_item].include?(command.tool)
      return false unless access.crm_scope(JrcCrm::Proposal).find(args.fetch('proposal_id')).status == 'draft'
    end

    JrcNico::CustomerRequestScope.validate!(access, command.source_notice, args)
    true
  end
end
