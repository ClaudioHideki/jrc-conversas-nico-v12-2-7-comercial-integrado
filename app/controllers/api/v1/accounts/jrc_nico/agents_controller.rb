class Api::V1::Accounts::JrcNico::AgentsController < Api::V1::Accounts::BaseController
  def index
    unless Current.user.is_a?(User)
      render json: { error: 'agent_forbidden' }, status: :forbidden
      return
    end
    render json: JrcNico::AgentCatalog.for_account(Current.account)
  end
end
