module JrcCrm
  class ActivityDispatchService
    def initialize(activity:, actor:)
      @activity = activity
      @actor = actor
      @account = activity.account
    end

    def call
      ActiveRecord::Base.transaction do
        @activity.save!
        JrcCrm::AuditLoggerService.new(
          account: @account,
          event_type: 'activity_created',
          actor: @actor,
          resource: @activity,
          from_value: nil,
          to_value: @activity.activity_type,
          metadata: { deal_id: @activity.deal_id, lead_id: @activity.lead_id }
        ).call
      end
      { success: true, activity: @activity }
    rescue ActiveRecord::RecordInvalid => e
      { success: false, error: e.record.errors.full_messages.to_sentence }
    end
  end
end
