class Api::V1::Accounts::Sales::SummaryController < Api::V1::Accounts::Sales::BaseController
  def show
    authorize SalesOpportunity
    opportunities = opportunity_scope.active
    open_opportunities = opportunities.where(status: 'open')
    overdue_activities = Current.account.sales_activities
                                        .where(sales_opportunity_id: opportunities.select(:id), status: 'scheduled')
                                        .where('scheduled_at < ?', Time.current)
    render json: {
      open_count: open_opportunities.count,
      open_value: open_opportunities.sum(:value),
      won_count: opportunities.where(status: 'won').count,
      lost_count: opportunities.where(status: 'lost').count,
      overdue_activities_count: overdue_activities.count
    }
  end
end
