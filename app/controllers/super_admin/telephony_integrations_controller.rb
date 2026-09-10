class SuperAdmin::TelephonyIntegrationsController < SuperAdmin::ApplicationController
  before_action :set_account

  def update
    integration = @account.telephony_integration || @account.build_telephony_integration
    attributes = integration_params.to_h
    attributes.delete('cdr_token') if attributes['cdr_token'].blank? && integration.persisted?
    integration.assign_attributes(attributes)
    integration.save!

    redirect_to configuration_path, notice: I18n.t('super_admin.telephony_integrations.saved')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to configuration_path, alert: e.record.errors.full_messages.to_sentence
  end

  def test_connection
    integration = @account.telephony_integration
    credential = eligible_credentials.first
    return redirect_to(configuration_path, alert: I18n.t('super_admin.telephony_integrations.missing')) if integration&.cdr_token.blank?
    return redirect_to(configuration_path, alert: I18n.t('super_admin.telephony_integrations.no_extension')) unless credential

    result = connection_test_result(integration, credential)
    redirect_to configuration_path,
                notice: I18n.t('super_admin.telephony_integrations.test_success', count: result[:count])
  rescue Hodupbx::CallHistoryService::Error => e
    redirect_to configuration_path, alert: safe_error_message(e.code)
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end

  def eligible_credentials
    @account.sip_credentials
            .where(enabled: true)
            .where.not(user_id: SuperAdmin.select(:id))
            .order(:user_id)
  end

  def integration_params
    params.require(:telephony_integration).permit(
      :provider, :history_enabled, :cdr_base_url, :cdr_api_version, :cdr_token, :tenant_type, :default_period_days
    )
  end

  def connection_test_result(integration, credential)
    test_integration = integration.dup
    test_integration.history_enabled = true
    Hodupbx::CallHistoryService.new(
      integration: test_integration,
      extension: credential.history_extension,
      start_date: Time.zone.today,
      end_date: Time.zone.today
    ).call
  end

  def configuration_path
    super_admin_sip_credentials_path(account_id: @account.id)
  end

  def safe_error_message(code)
    return I18n.t('super_admin.telephony_integrations.invalid_credentials') if code == :invalid_credentials
    return I18n.t('super_admin.telephony_integrations.timeout') if code == :timeout

    I18n.t('super_admin.telephony_integrations.test_error')
  end
end
