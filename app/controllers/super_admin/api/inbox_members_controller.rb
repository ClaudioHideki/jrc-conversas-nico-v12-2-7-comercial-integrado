class SuperAdmin::Api::InboxMembersController < SuperAdmin::Api::BaseController
  before_action :ensure_inbox!

  def show
    fetch_updated_agents
    render 'api/v1/accounts/inbox_members/show'
  end

  def create
    @inbox.add_members(agents_to_be_added_ids)
    fetch_updated_agents
    render 'api/v1/accounts/inbox_members/create'
  end

  def update
    @inbox.add_members(agents_to_be_added_ids)
    @inbox.remove_members(agents_to_be_removed_ids)
    fetch_updated_agents
    render 'api/v1/accounts/inbox_members/update'
  end

  def destroy
    @inbox.remove_members(super_admin_member_ids)
    head :ok
  end

  private

  def fetch_updated_agents
    @agents = current_account.users.where(id: @inbox.members.select(:user_id))
  end

  def current_agents_ids
    @current_agents_ids ||= @inbox.members.pluck(:id)
  end

  def requested_agent_ids
    @requested_agent_ids ||= super_admin_member_ids & current_account.users.pluck(:id)
  end

  def agents_to_be_added_ids
    requested_agent_ids - current_agents_ids
  end

  def agents_to_be_removed_ids
    current_agents_ids - requested_agent_ids
  end

  def super_admin_member_ids
    Array(params[:user_ids]).map(&:to_i)
  end
end
