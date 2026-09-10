class SuperAdmin::Api::Twitter::AuthorizationsController < Api::V1::Accounts::Twitter::AuthorizationsController
  skip_before_action :authenticate_user!
  skip_before_action :current_account
  skip_before_action :validate_token_api_access

  before_action :authenticate_super_admin!
  before_action :set_super_admin_current_context

  private

  def set_super_admin_current_context
    Current.user = current_super_admin
    Current.account = Account.find(params[:account_id])
    Current.account_user = nil
  end

  def check_authorization
    true
  end
end
