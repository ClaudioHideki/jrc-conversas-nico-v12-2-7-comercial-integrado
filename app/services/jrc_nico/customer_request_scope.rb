class JrcNico::CustomerRequestScope
  def self.validate!(access, notice, args)
    raise Pundit::NotAuthorizedError unless notice.visible_to?(access)
    conversation = access.conversation(notice.conversation.display_id)
    raise ArgumentError, 'A ação deve usar o contato desta conversa.' if args['contact_id'] && args['contact_id'] != conversation.contact_id
    raise ArgumentError, 'A ação deve usar esta conversa.' if args['conversation_id'] && args['conversation_id'] != conversation.display_id
    if args['conversation_ids'] && args['conversation_ids'].any? { |id| id != conversation.display_id }
      raise ArgumentError, 'A ação deve usar somente esta conversa.'
    end
    { 'lead_id' => JrcCrm::Lead, 'deal_id' => JrcCrm::Deal, 'proposal_id' => JrcCrm::Proposal }.each do |field, model|
      next unless args[field]
      record = access.crm_scope(model).find(args[field])
      contact_id = model == JrcCrm::Proposal ? record.deal.contact_id : record.contact_id
      raise ArgumentError, 'O registro não pertence ao cliente desta conversa.' unless contact_id == conversation.contact_id
    end
    if args['activity_id']
      activity = access.crm_scope(JrcCrm::Activity, owner: :user_id).find(args['activity_id'])
      ids = [activity.lead&.contact_id, activity.deal&.contact_id].compact
      raise ArgumentError, 'A atividade não pertence ao cliente desta conversa.' unless ids.include?(conversation.contact_id)
    end
    true
  end
end
