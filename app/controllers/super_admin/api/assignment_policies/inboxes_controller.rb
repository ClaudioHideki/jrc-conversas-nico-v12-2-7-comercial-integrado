class SuperAdmin::Api::AssignmentPolicies::InboxesController < SuperAdmin::Api::BaseController
  before_action :fetch_assignment_policy

  def index
    @inboxes = @assignment_policy.inboxes
    render 'api/v1/accounts/assignment_policies/inboxes/index'
  end

  private

  def fetch_assignment_policy
    @assignment_policy = current_account.assignment_policies.find(
      params[:assignment_policy_id]
    )
  end
end
