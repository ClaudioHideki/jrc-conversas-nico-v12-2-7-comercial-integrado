class Api::V1::Accounts::WhatsappCallingConfigurationsController < Api::V1::Accounts::BaseController
  def show
    configuration = Current.account.whatsapp_calling_configuration
    render json: {
      enabled: configuration&.enabled? || false,
      status: configuration&.configuration_status || 'not_configured',
      active: configuration&.ready? || false
    }
  end
end
