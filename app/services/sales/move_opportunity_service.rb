class Sales::MoveOpportunityService
  def initialize(opportunity:, stage:, user:, loss_reason: nil, loss_notes: nil)
    @opportunity = opportunity
    @stage = stage
    @user = user
    @loss_reason = loss_reason
    @loss_notes = loss_notes
  end

  def perform
    opportunity.with_lock do
      raise ActiveRecord::RecordInvalid, opportunity if stage.account_id != opportunity.account_id
      raise ActiveRecord::RecordInvalid, opportunity if stage.sales_pipeline_id != opportunity.sales_pipeline_id
      return opportunity if opportunity.sales_stage_id == stage.id

      previous_stage = opportunity.sales_stage
      status_attributes = status_attributes_for_stage
      opportunity.update!({ sales_stage: stage }.merge(status_attributes))
      opportunity.sales_stage_histories.create!(
        account: opportunity.account,
        from_stage: previous_stage,
        to_stage: stage,
        user: user,
        changed_at: Time.current
      )
      opportunity
    end
  end

  private

  attr_reader :opportunity, :stage, :user, :loss_reason, :loss_notes

  def status_attributes_for_stage
    case stage.stage_type
    when 'won'
      { status: 'won', won_at: Time.current, lost_at: nil, loss_reason: nil, loss_notes: nil }
    when 'lost'
      opportunity.errors.add(:loss_reason, 'is required when the opportunity is lost') if loss_reason.blank?
      raise ActiveRecord::RecordInvalid, opportunity if opportunity.errors.any?

      { status: 'lost', lost_at: Time.current, won_at: nil, loss_reason: loss_reason, loss_notes: loss_notes }
    else
      { status: 'open', won_at: nil, lost_at: nil, loss_reason: nil, loss_notes: nil }
    end
  end
end
