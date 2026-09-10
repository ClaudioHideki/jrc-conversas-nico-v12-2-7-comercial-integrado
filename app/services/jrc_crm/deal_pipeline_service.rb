module JrcCrm
  class DealPipelineService
    def initialize(deal:, stage:, actor:)
      @deal = deal
      @stage = stage
      @actor = actor
      @account = deal.account
    end

    def call
      return failure('Deal and stage must belong to the same account') unless @stage.account_id == @deal.account_id
      return failure('Deal and stage must belong to the same pipeline') unless @deal.pipeline_id == @stage.pipeline_id
      return failure('Target stage is not active') unless @stage.active?
      return failure('Lost reason is required when moving to a lost stage') if @stage.is_lost? && @deal.lost_reason_id.blank?

      from_stage_id = @deal.stage_id
      ActiveRecord::Base.transaction do
        attributes = {
 	 stage: @stage,
  	 probability: @stage.probability
	}
        attributes.merge!(status: 'won', won_at: Time.current, lost_at: nil) if @stage.is_won?
        attributes.merge!(status: 'lost', lost_at: Time.current, won_at: nil) if @stage.is_lost?
        attributes.merge!(status: 'open', won_at: nil, lost_at: nil, lost_reason: nil, lost_reason_note: nil) unless @stage.is_terminal?
        @deal.update!(attributes)
        JrcCrm::AuditLoggerService.new(
          account: @account,
          event_type: 'deal_stage_changed',
          actor: @actor,
          resource: @deal,
          from_value: from_stage_id,
          to_value: @stage.id
        ).call
      end
      { success: true, deal: @deal }
    rescue ActiveRecord::StaleObjectError
      failure('The deal was modified by another user. Please refresh and try again.')
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def failure(message)
      { success: false, error: message }
    end
  end
end
