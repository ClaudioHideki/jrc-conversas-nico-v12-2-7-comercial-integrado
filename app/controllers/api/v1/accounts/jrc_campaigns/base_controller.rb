class Api::V1::Accounts::JrcCampaigns::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_jrc_campaigns_enabled!
  before_action :ensure_campaign_administrator!

  private

  def ensure_campaign_administrator!
    return if Current.account_user&.administrator?

    render json: { errors: ['Somente administradores podem gerenciar campanhas.'] }, status: :forbidden
  end

  def ensure_jrc_campaigns_enabled!
    return if Current.account.feature_enabled?('jrc_campaigns')

    render json: { error: 'JRC Campanhas não está habilitado para esta conta' }, status: :forbidden
  end
end
