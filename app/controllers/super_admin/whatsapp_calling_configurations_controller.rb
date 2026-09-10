class SuperAdmin::WhatsappCallingConfigurationsController < SuperAdmin::ApplicationController
  before_action :set_account

  def show
    @accounts = Account.order(:name)
    @configuration = configuration
    @whatsapp_cloud_inboxes = whatsapp_cloud_inboxes
  end

  def update
    attributes = configuration_params.to_h
    attributes.delete('access_token') if attributes['access_token'].blank? && configuration.persisted?
    configuration.update!(attributes)
    enable_channel_voice_feature! if configuration.ready?

    redirect_to configuration_path, notice: I18n.t('super_admin.whatsapp_calling.configuration_saved')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to configuration_path, alert: e.record.errors.full_messages.to_sentence
  end

  def test_configuration
    return redirect_to configuration_path, alert: I18n.t('super_admin.whatsapp_calling.complete_before_test') unless configuration.complete?

    Whatsapp::CallingConfigurationTestService.new(configuration).perform
    configuration.update!(configuration_status: 'configured')
    enable_channel_voice_feature! if configuration.enabled?
    redirect_to configuration_path, notice: I18n.t('super_admin.whatsapp_calling.validated')
  rescue Whatsapp::CallingConfigurationTestService::Error => e
    configuration.update!(configuration_status: 'error')
    redirect_to configuration_path, alert: e.message
  end

  def enable_inbox_calling
    raise I18n.t('super_admin.whatsapp_calling.configuration_required') unless configuration.ready?

    enable_channel_voice_feature!
    inbox = whatsapp_cloud_inboxes.find { |candidate| candidate.id == params[:inbox_id].to_i }
    raise ActiveRecord::RecordNotFound unless inbox

    inbox.channel.enable_voice_calling!
    redirect_to configuration_path, notice: I18n.t('super_admin.whatsapp_calling.inbox_enabled')
  rescue StandardError => e
    redirect_to configuration_path, alert: e.message
  end

  def disable_inbox_calling
    inbox = whatsapp_cloud_inboxes.find { |candidate| candidate.id == params[:inbox_id].to_i }
    raise ActiveRecord::RecordNotFound unless inbox

    inbox.channel.disable_voice_calling!
    redirect_to configuration_path, notice: I18n.t('super_admin.whatsapp_calling.inbox_disabled')
  rescue StandardError => e
    redirect_to configuration_path, alert: e.message
  end

  private

  def set_account
    @account = params[:account_id].present? ? Account.find(params[:account_id]) : Account.order(:name).first
    redirect_to(super_admin_accounts_path, alert: I18n.t('super_admin.whatsapp_calling.account_required')) unless @account
  end

  def configuration
    @configuration ||= @account.whatsapp_calling_configuration || @account.build_whatsapp_calling_configuration
  end

  def configuration_params
    params.require(:whatsapp_calling_configuration).permit(:enabled, :waba_id, :phone_number_id, :access_token)
  end

  def whatsapp_cloud_inboxes
    @whatsapp_cloud_inboxes ||= @account.inboxes.includes(:channel).select do |inbox|
      inbox.channel.is_a?(Channel::Whatsapp) && inbox.channel.provider == 'whatsapp_cloud'
    end
  end

  def enable_channel_voice_feature!
    @account.enable_features!('channel_voice') unless @account.feature_enabled?('channel_voice')
  end

  def configuration_path
    super_admin_whatsapp_calling_configuration_path(account_id: @account.id)
  end
end
