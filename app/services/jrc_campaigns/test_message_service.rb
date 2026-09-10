class JrcCampaigns::TestMessageService
  CampaignContext = Data.define(:account)
  RecipientContext = Data.define(:campaign, :contact, :name, :phone_number)

  def initialize(account:, user:, phone_number:, inbox_id:, step:)
    @account = account
    @user = user
    @phone_number = JrcCampaigns::PhoneNormalizer.call(phone_number)
    @inbox = account.inboxes.includes(:channel).find(inbox_id)
    @step = step.to_h.with_indifferent_access
  end

  def perform
    raise ArgumentError, 'Informe um número válido para o teste.' if phone_number.blank?
    raise ArgumentError, 'A caixa selecionada não é WhatsApp.' unless channel.is_a?(Channel::Whatsapp)

    rejection = eligibility.rejection_reason
    raise ArgumentError, rejection if rejection

    message_id = step[:kind] == 'template' ? send_template : send_freeform
    raise StandardError, proxy.external_error.presence || 'O provedor não confirmou o envio do teste.' if message_id.blank?

    { message_id: message_id, inbox_id: inbox.id, phone_number: phone_number }
  end

  private

  attr_reader :account, :user, :phone_number, :inbox, :step

  def channel
    inbox.channel
  end

  def renderer
    campaign = CampaignContext.new(account: account)
    recipient = RecipientContext.new(campaign: campaign, contact: nil, name: user.name, phone_number: phone_number)
    @renderer ||= JrcCampaigns::TemplateRenderer.new(recipient: recipient, inbox: inbox)
  end

  def proxy
    @proxy ||= JrcCampaigns::ProviderMessageProxy.new(
      kind: step[:kind],
      body: renderer.render(effective_value(:body)),
      media_url: effective_value(:media_url),
      file_name: effective_value(:file_name)
    )
  end

  def send_freeform
    eligibility.freeform_conversation!(inbox)
    channel.send_message(phone_number, proxy)
  end

  def eligibility
    @eligibility ||= JrcCampaigns::EligibilityPolicy.new(account: account, phone_number: phone_number)
  end

  def send_template
    raw_params = effective_value(:template_params).to_h.deep_stringify_keys
    raw_params['name'] = effective_value(:template_name)
    raw_params['namespace'] = effective_value(:template_namespace)
    raw_params['language'] = effective_value(:template_language)
    name, namespace, lang_code, parameters = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: renderer.render(raw_params)
    ).call
    raise ArgumentError, 'Template não aprovado ou não encontrado na caixa selecionada.' if name.blank?

    channel.send_template(
      phone_number,
      { name: name, namespace: namespace, lang_code: lang_code, parameters: parameters },
      proxy
    )
  end

  def effective_value(field)
    overrides = step[:inbox_overrides].to_h.with_indifferent_access
    inbox_override = overrides[inbox.id.to_s].to_h.with_indifferent_access
    inbox_override[field].presence || step[field]
  end
end
