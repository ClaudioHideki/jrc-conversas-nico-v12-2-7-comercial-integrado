module JrcCrm
  class TimelineAggregatorService
    def initialize(resource:)
      @resource = resource
      @account = resource.account
    end

    def call
      events = []

      # 1. Activities
      if @resource.respond_to?(:activities)
        @resource.activities.each do |activity|
          events << {
            type: 'activity',
            date: activity.created_at,
            data: JrcCrm::ActivitySerializer.new(activity).as_json
          }
        end
      end

      # 2. Audit Events
      audit_events = JrcCrm::AuditEvent.where(resource_type: @resource.class.name, resource_id: @resource.id)
      audit_events.each do |event|
        events << {
          type: 'audit',
          date: event.created_at,
          data: JrcCrm::AuditEventSerializer.new(event).as_json
        }
      end

      # 3. Proposals (if deal)
      if @resource.is_a?(JrcCrm::Deal)
        @resource.proposals.each do |proposal|
          events << {
            type: 'proposal_created',
            date: proposal.created_at,
            data: { proposal_id: proposal.id, title: proposal.title, status: proposal.status }
          }
          proposal.events.each do |pe|
            events << {
              type: "proposal_#{pe.event_type}",
              date: pe.created_at,
              data: { proposal_id: proposal.id, user_id: pe.user_id, description: pe.description, metadata: pe.metadata }
            }
          end
        end
      end

      # 4. Conversations (JRC Conversas linked)
      # Assuming a polymorphic association or join table for linked conversations
      if @resource.respond_to?(:conversations)
        @resource.conversations.each do |conversation|
          events << {
            type: 'conversation',
            date: conversation.created_at,
            data: {
              conversation_id: conversation.id,
              inbox_id: conversation.inbox_id,
              status: conversation.status
            }
          }
        end
      end

      # Sort by date descending
      events.sort_by { |e| e[:date] }.reverse
    end
  end
end
