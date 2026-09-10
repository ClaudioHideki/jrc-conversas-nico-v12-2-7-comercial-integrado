class Api::V1::Accounts::Sales::MetadataController < Api::V1::Accounts::Sales::BaseController
  def show
    users = Current.account_user.administrator? ? Current.account.users : Current.account.users.where(id: Current.user.id)
    teams = Current.account_user.administrator? ? Current.account.teams : Current.user.teams.where(account_id: Current.account.id)
    render json: {
      users: users.order(:name).map { |user| { id: user.id, name: user.name } },
      teams: teams.order(:name).map { |team| { id: team.id, name: team.name } }
    }
  end
end
