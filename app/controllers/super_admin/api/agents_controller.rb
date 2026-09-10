class SuperAdmin::Api::AgentsController < SuperAdmin::Api::BaseController
  def index
    @agents = current_account.users.order_by_full_name.includes(:account_users, { avatar_attachment: [:blob] })
    render 'api/v1/accounts/agents/index'
  end
end
