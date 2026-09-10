class Api::V1::Accounts::Sales::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_sales_enabled
  around_action :use_account_timezone

  private

  def ensure_sales_enabled
    render json: { error: 'Sales module is not enabled for this account' }, status: :forbidden unless Current.account.feature_enabled?('sales')
  end

  def opportunity_scope
    policy_scope(Current.account.sales_opportunities)
  end

  def use_account_timezone(&block)
    timezone = ActiveSupport::TimeZone[Current.account.reporting_timezone] || Time.zone
    Time.use_zone(timezone, &block)
  end

  def serialize_stage(stage)
    {
      id: stage.id,
      name: stage.name,
      position: stage.position,
      color: stage.color,
      stage_type: stage.stage_type,
      active: stage.active
    }
  end

  def serialize_activity(activity)
    {
      id: activity.id,
      opportunity_id: activity.sales_opportunity_id,
      contact_id: activity.contact_id,
      owner: activity.owner && { id: activity.owner.id, name: activity.owner.name },
      activity_type: activity.activity_type,
      title: activity.title,
      scheduled_at: activity.scheduled_at,
      status: activity.effective_status,
      stored_status: activity.status,
      notes: activity.notes,
      completed_at: activity.completed_at
    }
  end

  def serialize_opportunity(opportunity, details: false)
    contact = opportunity.contact
    identity = contact.name.presence || contact.identifier.presence || contact.email.presence || contact.phone_number.presence
    next_activity = opportunity.next_activity
    data = {
      id: opportunity.id,
      title: opportunity.title,
      pipeline_id: opportunity.sales_pipeline_id,
      stage: serialize_stage(opportunity.sales_stage),
      contact: {
        id: contact.id,
        name: identity,
        company: contact.try(:company)&.name || contact.additional_attributes&.dig('company_name'),
        identifier: contact.identifier,
        email: contact.email,
        phone_number: contact.phone_number,
        thumbnail: contact.avatar_url
      },
      conversation_id: opportunity.conversation_id,
      conversation_display_id: opportunity.conversation&.display_id,
      inbox_id: opportunity.inbox_id,
      owner: opportunity.owner && { id: opportunity.owner.id, name: opportunity.owner.name },
      team: opportunity.team && { id: opportunity.team.id, name: opportunity.team.name },
      product_name: opportunity.product_name,
      value: opportunity.value,
      temperature: opportunity.temperature,
      source_channel: opportunity.source_channel,
      status: opportunity.status,
      notes: opportunity.notes,
      won_at: opportunity.won_at,
      lost_at: opportunity.lost_at,
      loss_reason: opportunity.loss_reason && { id: opportunity.loss_reason.id, name: opportunity.loss_reason.name },
      loss_notes: opportunity.loss_notes,
      archived_at: opportunity.archived_at,
      next_activity: next_activity && serialize_activity(next_activity),
      created_at: opportunity.created_at,
      updated_at: opportunity.updated_at
    }
    return data unless details

    data.merge(
      activities: opportunity.sales_activities.sort_by(&:scheduled_at).map { |activity| serialize_activity(activity) },
      stage_history: opportunity.sales_stage_histories.sort_by(&:changed_at).reverse.map do |history|
        {
          id: history.id,
          from_stage: history.from_stage && serialize_stage(history.from_stage),
          to_stage: serialize_stage(history.to_stage),
          user: { id: history.user.id, name: history.user.name },
          changed_at: history.changed_at
        }
      end
    )
  end
end
