class SuperAdmin::Api::TeamsController < SuperAdmin::Api::BaseController
  def index
    @teams = current_account.teams
    render 'api/v1/accounts/teams/index'
  end
end
