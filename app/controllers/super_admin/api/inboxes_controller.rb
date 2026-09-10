class SuperAdmin::Api::InboxesController < Api::V1::Accounts::InboxesController
  skip_before_action :authenticate_user!
  skip_before_action :current_account
  skip_before_action :validate_token_api_access
  skip_before_action :check_authorization
  before_action :authenticate_super_admin!
  before_action :set_super_admin_current_context

  def index
    @inboxes = Current.account.inboxes
               .includes(:channel, :portal, :working_hours, { avatar_attachment: :blob })
               .order_by_name
    render 'api/v1/accounts/inboxes/index'
  end

  def show
    render 'api/v1/accounts/inboxes/show'
  end

  def assignable_agents
    super
    render 'api/v1/accounts/inboxes/assignable_agents'
  end

  def campaigns
    super
    render 'api/v1/accounts/inboxes/campaigns'
  end

  def create
    super
    render 'api/v1/accounts/inboxes/create'
  end

  def update
    super
    render 'api/v1/accounts/inboxes/update' unless performed?
  end

  def agent_bot
    super
    render 'api/v1/accounts/inboxes/agent_bot'
  end

  def reset_secret
    super
    render 'api/v1/accounts/inboxes/reset_secret'
  end

  private

  def set_super_admin_current_context
    Current.user = current_super_admin
    Current.account = Account.find(params[:account_id])
    Current.account_user = nil
  end

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:id])
  end

  def check_authorization(_model = nil)
    true
  end

  def check_admin_authorization?
    true
  end
end
