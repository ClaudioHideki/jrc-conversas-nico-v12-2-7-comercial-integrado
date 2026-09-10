class Api::V1::Accounts::JrcCopilotController < Api::V1::Accounts::BaseController
  def ask
    result = JrcCopilot::AssistantService.new(
      account: Current.account,
      user: Current.user,
      message: copilot_params.fetch(:message),
      route_name: copilot_params[:route_name],
      route_path: copilot_params[:route_path],
      page_context: copilot_params[:context] || {},
      history: copilot_params[:history] || []
    ).perform

    render json: result
  end

  def context
    render json: JrcCopilot::TaskCatalog.context(params[:route_name]).merge(
      ai_configured: ai_configured?,
      nico_enabled: Current.account.custom_attributes['nico_enabled'] == true,
      can_manage_ai: Current.account_user&.administrator?
    )
  end

  private

  def ai_configured?
    Current.account.jrc_ai_providers.enabled.any?(&:api_key_configured?)
  rescue StandardError
    false
  end

  def copilot_params
    params.permit(
      :message,
      :route_name,
      :route_path,
      context: {},
      history: [:role, :content]
    ).tap do |permitted|
      raise ActionController::ParameterMissing, :message if permitted[:message].blank?
    end
  end
end
