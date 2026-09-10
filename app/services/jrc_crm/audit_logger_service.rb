module JrcCrm
  class AuditLoggerService
    def initialize(account:, event_type:, actor:, resource:, from_value:, to_value:, metadata: {}, ip_address: nil)
      @account = account
      @event_type = event_type
      @actor = actor
      @resource = resource
      @from_value = from_value
      @to_value = to_value
      @metadata = metadata
      @ip_address = ip_address
    end

    def call
      JrcCrm::AuditEvent.create!(
        account_id: @account.id,
        event_type: @event_type,
        actor_type: @actor&.class&.name || 'System',
        actor_id: @actor&.id,
        resource_type: @resource.class.name,
        resource_id: @resource.id,
        from_value: @from_value.to_s,
        to_value: @to_value.to_s,
        metadata: @metadata,
        ip_address: @ip_address
      )
    rescue StandardError => e
      Rails.logger.error("Failed to create audit event: #{e.message}")
    end
  end
end
