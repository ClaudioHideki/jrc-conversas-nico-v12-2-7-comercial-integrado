class JrcFlows::Delivery
  def initialize(message)
    @message = message
    # A newly created conversation may still carry a dirty, callback-assigned display_id.
    # Delivery locks persisted state without modifying the caller's association.
    @conversation = Conversation.find(message.conversation_id)
  end

  def perform
    claimed = @conversation.with_lock do
      @message.reload
      next false unless @message.content_attributes['jrc_flow_delivery'] == 'queued'
      unless allowed?
        mark!('cancelled', failed: true)
        next false
      end
      mark!('dispatching')
      true
    end
    return unless claimed

    # Claim is committed before external I/O. Uncertain sends are never retried automatically.
    @conversation.with_lock do
      unless allowed?
        mark!('cancelled', failed: true)
        next
      end
      yield
      @message.reload
      mark!(@message.failed? ? 'failed' : 'channel_processed')
    end
  rescue StandardError => e
    Rails.logger.warn("JRC Flows delivery=#{@message.id} failed: #{e.class}")
    mark!('unknown', failed: true)
  end

  private

  def allowed?
    run = JrcFlowRun.find_by(id: @message.content_attributes['jrc_flow_run_id'],
                            account_id: @message.account_id, conversation_id: @conversation.id)
    return false unless run && %w[running waiting delayed completed].include?(run.status)
    return false unless run.flow.status == 'active' && run.flow.lock_version == run.settings['_flow_version']
    return false unless JrcFlows::Access.enabled?(run.account) && run.account.account_users.exists?(user_id: run.flow.created_by_id, role: 'administrator')
    return false if @conversation.messages.outgoing.where(sender_type: 'User', private: false).where('id > ?', @message.id).exists?

    # A handoff performed by this exact flow may precede delivery of its last message.
    final = run.graph['nodes'].find { |node| node['id'] == run.trace.last&.fetch('node_id', nil) }
    own_assignment = run.status == 'completed' && final&.fetch('type') == 'assign' &&
      (final['data']['agent_id'].blank? || final['data']['agent_id'].to_i == @conversation.assignee_id) &&
      (final['data']['team_id'].blank? || final['data']['team_id'].to_i == @conversation.team_id)
    own_assignment ||= run.status == 'completed' && run.flow.engine == 'workflow' &&
      run.variables['_workflow_handoff_team'].present? && run.variables['_workflow_handoff_team'] == @conversation.team_id
    if @conversation.assignee_agent_bot_id.present?
      return run.status == 'completed' && final&.fetch('type') == 'nico' &&
        JrcNico::Delegation.exists?(conversation: @conversation, user_id: run.flow.created_by_id,
                                   agent_bot_id: @conversation.assignee_agent_bot_id, status: 'active')
    end
    return false if run.settings.fetch('pause_on_agent', true) && @conversation.assignee_id.present? && !own_assignment
    return false if run.settings.fetch('pause_on_team', false) && @conversation.team_id.present? && !own_assignment

    true
  end

  def mark!(state, failed: false)
    attrs = @message.reload.content_attributes.to_h.merge('jrc_flow_delivery' => state)
    attrs['external_error'] = 'Flow: envio cancelado ou resultado de entrega não confirmado.' if failed
    @message.update!(content_attributes: attrs, **(failed ? { status: :failed } : {}))
  end
end
