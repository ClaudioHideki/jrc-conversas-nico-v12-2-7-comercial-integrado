module JrcCrm
  class AuditEventSerializer
    def initialize(audit_event)
      @audit_event = audit_event
    end

    def as_json(options = {})
      {
        id: @audit_event.id,
        event_type: @audit_event.event_type,
        actor_type: @audit_event.actor_type,
        actor_id: @audit_event.actor_id,
        resource_type: @audit_event.resource_type,
        resource_id: @audit_event.resource_id,
        from_value: @audit_event.from_value,
        to_value: @audit_event.to_value,
        metadata: @audit_event.metadata,
        created_at: @audit_event.created_at,
        created_at_display: format_datetime(@audit_event.created_at)
      }
    end

    private

    def format_datetime(value)
      return nil unless value

      I18n.l(value.in_time_zone, format: '%d/%m/%Y %H:%M')
    end
  end
end
