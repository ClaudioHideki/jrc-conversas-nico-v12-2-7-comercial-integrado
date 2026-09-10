class JrcCampaigns::DispatchStepService
  def initialize(recipient:, step:)
    @recipient = recipient
    @step = step
    @campaign = recipient.campaign
    @inbox = recipient.inbox
  end

  def perform
    @provider_attempted = false
    @accepted_external_id = nil
    delivery = recipient.deliveries.find_by(step: step)
    return reconcile_delivery(delivery) if delivery&.sent_at.present?

    campaign.reload
    return if campaign.canceled?

    if campaign.paused?
      recipient.update!(metadata: recipient.metadata.to_h.merge('pending_step_id' => step.id))
      return
    end
    return if recipient.status.in?(%w[failed canceled skipped])
    return if delivery && !delivery.queued?

    recipient.update!(metadata: recipient.metadata.to_h.except('pending_step_id')) if recipient.metadata.to_h.key?('pending_step_id')
    if step.only_if_no_reply? && recipient.replied_at.present?
      JrcCampaigns::ExecutionCompletionService.new(recipient.execution).check!
      return
    end

    delivery = claim_delivery
    return unless delivery
    return if defer_for_campaign_state(delivery)

    rejection = sending_rejection
    return skip_delivery(delivery, rejection) if rejection

    @accepted_external_id = dispatch_message
    raise 'O provedor não retornou o identificador da mensagem' if @accepted_external_id.blank?

    delivery.update!(external_id: @accepted_external_id, status: 'sent', sent_at: Time.current, error_message: nil)
    reconcile_delivery(delivery)
  rescue StandardError => e
    handle_failure(delivery, e)
  end

  private

  attr_reader :recipient, :step, :campaign, :inbox

  def claim_delivery
    # Commit the claim before crossing the provider boundary. A crashed/overlapping
    # job must never reclaim a request whose external outcome could be unknown.
    recipient.with_lock do
      delivery = recipient.deliveries.find_or_initialize_by(step: step)
      next unless delivery.new_record? || delivery.queued?

      delivery.update!(inbox: inbox, status: 'sending')
      recipient.update!(status: 'processing', metadata: recipient.metadata.to_h.except('pending_step_id'))
      delivery
    end
  end

  def sending_rejection
    campaign.reload.ensure_approved!
    eligibility.rejection_reason
  rescue ActiveRecord::RecordInvalid => e
    e.record.errors.full_messages.join(', ')
  end

  def defer_for_campaign_state(delivery)
    campaign.reload
    return false if campaign.running?

    recipient.with_lock do
      if campaign.paused?
        delivery.update!(status: 'queued')
        recipient.update!(status: 'queued', metadata: recipient.metadata.to_h.merge('pending_step_id' => step.id))
      else
        delivery.update!(status: 'skipped', error_message: 'Campanha não está em execução.')
        recipient.update!(status: campaign.canceled? ? 'canceled' : 'skipped', metadata: recipient.metadata.to_h.except('pending_step_id'))
      end
    end
    true
  end

  def eligibility
    JrcCampaigns::EligibilityPolicy.new(account: campaign.account, phone_number: recipient.phone_number, contact: recipient.contact)
  end

  def skip_delivery(delivery, reason)
    delivery.update!(status: 'skipped', error_message: reason)
    recipient.update!(status: 'skipped', error_message: reason, metadata: recipient.metadata.to_h.except('pending_step_id'))
    JrcCampaigns::ExecutionCompletionService.new(recipient.execution).check!
  end

  def reconcile_delivery(delivery)
    recipient.with_lock do
      delivery.reload
      next if delivery.metadata.to_h['reconciled_at'].present?

      status = recipient.status.in?(%w[delivered read replied failed]) ? recipient.status : 'sent'
      recipient.update!(status: status, sent_at: recipient.sent_at || delivery.sent_at,
                        error_message: recipient.failed? ? recipient.error_message : nil)
      JrcCampaigns::EventLogger.call(
        campaign: campaign, execution: recipient.execution, recipient: recipient, event_type: 'message_sent',
        payload: { step_id: step.id, external_id: delivery.external_id, inbox_id: inbox.id, kind: step.kind }
      )
      attach_existing_conversation
      create_conversation_if_requested
      record_conversation_message(delivery, delivery.external_id)
      advance_execution
      delivery.update!(metadata: delivery.metadata.to_h.except('reconciliation_error').merge('reconciled_at' => Time.current.iso8601))
    end
  end

  def advance_execution
    return if campaign.reload.canceled?
    return JrcCampaigns::ExecutionCompletionService.new(recipient.execution).check! if recipient.failed?

    schedule_next_step_or_finish
  end

  def dispatch_message
    channel = inbox.channel
    raise 'A caixa selecionada não é WhatsApp' unless channel.is_a?(Channel::Whatsapp)

    if step.kind == 'template'
      send_template(channel)
    else
      ensure_freeform_allowed!
      body = renderer.render(effective_value('body', step.body))
      proxy = JrcCampaigns::ProviderMessageProxy.new(
        kind: step.kind,
        body: body,
        media_url: effective_value('media_url', step.media_url),
        file_name: effective_value('file_name', step.file_name)
      )
      @provider_attempted = true
      external_id = channel.send_message(recipient.phone_number, proxy)
      raise proxy.external_error if external_id.blank? && proxy.external_error.present?

      external_id
    end
  end

  def send_template(channel)
    raw_params = effective_value('template_params', step.template_params).deep_dup
    raw_params['name'] = effective_value('template_name', step.template_name)
    raw_params['namespace'] = effective_value('template_namespace', step.template_namespace)
    raw_params['language'] = effective_value('template_language', step.template_language)
    rendered_params = renderer.render(raw_params)
    name, namespace, lang_code, parameters = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: rendered_params
    ).call
    raise 'Template não aprovado ou não encontrado na caixa selecionada' if name.blank?

    proxy = JrcCampaigns::ProviderMessageProxy.new(kind: 'text', body: '')
    @provider_attempted = true
    external_id = channel.send_template(
      recipient.phone_number,
      { name: name, namespace: namespace, lang_code: lang_code, parameters: parameters },
      proxy
    )
    raise proxy.external_error if external_id.blank? && proxy.external_error.present?

    external_id
  end

  def ensure_freeform_allowed!
    conversation = eligibility.freeform_conversation!(inbox)
    recipient.update!(conversation: conversation) unless recipient.conversation_id == conversation.id
  end

  def renderer
    @renderer ||= JrcCampaigns::TemplateRenderer.new(recipient: recipient, inbox: inbox)
  end

  def effective_value(key, fallback)
    override = step.inbox_overrides.to_h[inbox.id.to_s] || step.inbox_overrides.to_h[inbox.id]
    override&.fetch(key, nil).presence || fallback
  end

  def schedule_next_step_or_finish
    next_step = campaign.steps.where('position > ?', step.position).order(:position).first
    if next_step
      wait_time = if next_step.only_if_no_reply? && next_step.follow_up_after_hours.present?
                    next_step.follow_up_after_hours.hours
                  else
                    step.delay_after_seconds.seconds
                  end
      target_time = JrcCampaigns::ScheduleWindow.new(campaign).next_time(Time.current + wait_time)
      recipient.update!(metadata: recipient.metadata.to_h.merge('pending_step_id' => next_step.id))
      JrcCampaigns::DispatchStepJob.set(wait_until: target_time).perform_later(recipient.id, next_step.id)
    else
      JrcCampaigns::ExecutionCompletionService.new(recipient.execution).check!
    end
  end

  def attach_existing_conversation
    return if recipient.conversation_id.present? || recipient.contact.blank?

    conversation = recipient.contact.conversations.where(inbox_id: inbox.id).order(updated_at: :desc).first
    recipient.update!(conversation: conversation) if conversation
  end

  def record_conversation_message(delivery, external_id)
    conversation = recipient.conversation
    return unless conversation
    return if conversation.messages.exists?(source_id: external_id)

    message = conversation.messages.build(
      account: campaign.account,
      inbox: inbox,
      sender: nil,
      message_type: step.kind == 'template' ? 'template' : 'outgoing',
      content: conversation_message_content,
      source_id: external_id,
      additional_attributes: {
        'jrc_campaign_id' => campaign.id,
        'jrc_campaign_execution_id' => recipient.execution_id,
        'jrc_campaign_step_id' => step.id
      }
    )
    add_external_attachment(message)
    message.save!
    delivery.update!(metadata: delivery.metadata.to_h.merge('message_id' => message.id))
  end

  def conversation_message_content
    body = renderer.render(effective_value('body', step.body)).to_s
    return body if body.present?

    step.template_name.to_s
  end

  def add_external_attachment(message)
    return unless %w[image document video audio].include?(step.kind)

    file_type = { 'image' => 'image', 'video' => 'video', 'document' => 'file', 'audio' => 'file' }.fetch(step.kind)
    message.attachments.build(
      account: campaign.account,
      file_type: file_type,
      external_url: effective_value('media_url', step.media_url)
    )
  end

  def create_conversation_if_requested
    return if campaign.conversation_mode == 'reply_only'
    return if recipient.conversation_id.present?
    return unless recipient.contact

    contact_inbox = recipient.contact.contact_inboxes.find_or_create_by!(inbox: inbox) do |record|
      record.source_id = recipient.phone_number.delete_prefix('+')
    end
    conversation = recipient.contact.conversations.where(inbox_id: inbox.id).order(created_at: :desc).first
    conversation ||= Conversation.create!(
      account: campaign.account,
      inbox: inbox,
      contact: recipient.contact,
      contact_inbox: contact_inbox,
      status: campaign.conversation_mode == 'pending' ? 'pending' : 'open'
    )
    recipient.update!(conversation: conversation)
  end

  def handle_failure(delivery, error)
    if @accepted_external_id.present? && delivery.reload.sent_at.blank?
      delivery.update!(external_id: @accepted_external_id, status: 'sent', sent_at: Time.current)
    end
    return reconcile_later(delivery, error) if delivery&.sent_at.present?

    if @provider_attempted
      delivery.update!(status: 'unknown', error_message: error.message)
      recipient.update!(error_message: "Resultado do provedor desconhecido; reenvio automático bloqueado: #{error.message}")
      return
    end

    fail_delivery(error)
  end

  def reconcile_later(delivery, error)
    attempts = delivery.metadata.to_h.fetch('reconciliation_attempts', 0).to_i + 1
    delivery.update!(metadata: delivery.metadata.to_h.merge('reconciliation_error' => error.message, 'reconciliation_attempts' => attempts))
    recipient.update!(error_message: "Enviado; sincronização local pendente: #{error.message}")
    JrcCampaigns::DispatchStepJob.set(wait: 1.minute).perform_later(recipient.id, step.id) if attempts <= 5
  end

  def fail_delivery(error)
    delivery = recipient.deliveries.find_or_initialize_by(step: step)
    delivery.inbox ||= inbox
    delivery.update!(status: 'failed', failed_at: Time.current, error_message: error.message)
    recipient.update!(status: 'failed', failed_at: Time.current, error_message: error.message)
    JrcCampaigns::EventLogger.call(
      campaign: campaign,
      execution: recipient.execution,
      recipient: recipient,
      event_type: 'message_failed',
      payload: { step_id: step.id, error: error.message }
    )
    JrcCampaigns::ExecutionCompletionService.new(recipient.execution).check!
  end
end
