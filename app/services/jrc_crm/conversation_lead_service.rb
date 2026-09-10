class JrcCrm::ConversationLeadService
  CHANNEL_SOURCES = {
    'Channel::Email' => 'email',
    'Channel::FacebookPage' => 'facebook',
    'Channel::Instagram' => 'instagram',
    'Channel::Telegram' => 'telegram',
    'Channel::Whatsapp' => 'whatsapp'
  }.freeze

  def initialize(account:, conversation:, actor:)
    @account = account
    @conversation = conversation
    @actor = actor
  end

  def call
    existing_lead = find_existing_lead
    return { lead: existing_lead, created: false } if existing_lead

    lead = create_lead
    log_creation(lead)
    { lead: lead, created: true }
  rescue ActiveRecord::RecordNotUnique
    { lead: find_existing_lead!, created: false }
  end

  private

  def create_lead
    @account.jrc_crm_leads.create!(
      owner: @conversation.assignee || @actor,
      contact: @conversation.contact,
      conversation: @conversation,
      team: @conversation.team,
      name: contact_name,
      company_name: @conversation.contact.company&.name,
      email: @conversation.contact.email,
      phone: @conversation.contact.phone_number,
      source: source,
      idempotency_key: idempotency_key,
      classified_at: Time.current,
      custom_attributes: conversation_snapshot
    )
  end

  def contact_name
    contact = @conversation.contact
    contact.name.presence || contact.identifier.presence || contact.email.presence ||
      contact.phone_number.presence || "Contato ##{contact.id}"
  end

  def source
    channel_type = @conversation.inbox.channel_type
    return 'whatsapp' if @conversation.inbox.twilio_whatsapp?

    CHANNEL_SOURCES.fetch(channel_type, channel_type.to_s.remove('Channel::').underscore.presence || 'conversation')
  end

  def idempotency_key
    "conversation:#{@conversation.id}"
  end

  def conversation_snapshot
    {
      'source_channel' => source,
      'source_inbox_id' => @conversation.inbox_id,
      'source_inbox_name' => @conversation.inbox.name,
      'last_message' => @conversation.messages.where.not(content: [nil, '']).order(created_at: :desc).pick(:content),
      'classified_by_id' => @actor.id
    }.compact
  end

  def find_existing_lead
    @account.jrc_crm_leads.find_by(idempotency_key: idempotency_key) ||
      @account.jrc_crm_leads.find_by(conversation_id: @conversation.id)
  end

  def find_existing_lead!
    @account.jrc_crm_leads.find_by!(idempotency_key: idempotency_key)
  end

  def log_creation(lead)
    JrcCrm::AuditLoggerService.new(
      account: @account,
      event_type: 'lead_created',
      actor: @actor,
      resource: lead,
      from_value: nil,
      to_value: 'new',
      metadata: { source: 'conversation', conversation_id: @conversation.id }
    ).call
  end
end
