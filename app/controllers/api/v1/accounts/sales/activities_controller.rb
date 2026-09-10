class Api::V1::Accounts::Sales::ActivitiesController < Api::V1::Accounts::Sales::BaseController
  before_action :set_opportunity, only: :create
  before_action :set_activity, only: :update

  def create
    authorize @opportunity, :update?
    owner = Current.user
    owner = Current.account.users.find(activity_params[:owner_id]) if Current.account_user.administrator? && activity_params[:owner_id].present?
    activity = @opportunity.sales_activities.new(activity_params.except(:owner_id))
    activity.assign_attributes(account: Current.account, contact: @opportunity.contact, owner: owner)
    activity.save!
    render json: serialize_activity(activity), status: :created
  end

  def update
    authorize @activity.sales_opportunity, :update?
    attributes = activity_params.except(:owner_id)
    if Current.account_user.administrator? && activity_params[:owner_id].present?
      attributes[:owner] = Current.account.users.find(activity_params[:owner_id])
    end
    attributes[:completed_at] = Time.current if attributes[:status] == 'completed'
    attributes[:completed_at] = nil if attributes[:status].present? && attributes[:status] != 'completed'
    @activity.update!(attributes)
    render json: serialize_activity(@activity)
  end

  private

  def set_opportunity
    @opportunity = opportunity_scope.find(params[:opportunity_id])
  end

  def set_activity
    @activity = Current.account.sales_activities.includes(:sales_opportunity).find(params[:id])
  end

  def activity_params
    params.require(:activity).permit(:activity_type, :title, :scheduled_at, :status, :notes, :owner_id)
  end
end
