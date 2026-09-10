class JrcNicoListener < BaseListener
  def conversation_updated(event)
    conversation, = extract_conversation_and_account(event)
    conversation.reload # Events can be queued before the final bot/status assignment commits.
    delegation = JrcNico::Delegation.find_by(conversation: conversation, status: 'active')
    return unless delegation
    return if conversation.pending? && conversation.assignee_agent_bot_id == delegation.agent_bot_id

    JrcNico::DelegationService.stop(conversation, reason: 'conversation_changed')
  end

  alias conversation_status_changed conversation_updated

  def message_created(event)
    message, account = extract_message_and_account(event)
    return unless account.custom_attributes['nico_enabled'] == true
    delegation = JrcNico::Delegation.find_by(conversation_id: message.conversation_id, account_id: account.id)
    if delegation&.live? && message.incoming? && !message.private?
      JrcNico::CustomerTurnJob.set(wait: 2.seconds).perform_later(delegation.id)
      return
    end
    return unless message.incoming? && !message.private? && message.content.present?

    allowed_inboxes = Array(account.custom_attributes['nico_inbox_ids']).map(&:to_i)
    return if allowed_inboxes.any? && allowed_inboxes.exclude?(message.inbox_id)

    recommendation = JrcNico::IntentClassifier.call(message)
    message.conversation.with_lock do
      attributes = message.conversation.custom_attributes.to_h
      message.conversation.update!(custom_attributes: attributes.merge('nico_assistance' => recommendation))
    end
  end
end
