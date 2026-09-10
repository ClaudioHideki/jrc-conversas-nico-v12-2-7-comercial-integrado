module JrcCrm
  class Customer360Service
    def initialize(resource:)
      @resource = resource
      @account = resource.account
    end

    def call
      {
        profile: profile_data,
        metrics: calculate_metrics,
        recent_deals: fetch_deals,
        recent_proposals: fetch_proposals,
        recent_activities: fetch_activities,
        conversation_history: fetch_conversations,
        timeline: JrcCrm::TimelineAggregatorService.new(resource: @resource).call
      }
    end

    private

    def profile_data
      {
        id: @resource.id,
        name: @resource.name,
        email: @resource.respond_to?(:email) ? @resource.email : nil,
        phone: @resource.respond_to?(:phone_number) ? @resource.phone_number : nil,
        created_at: @resource.created_at
      }
    end

    def calculate_metrics
      deals = @resource.respond_to?(:deals) ? @resource.deals : []
      
      {
        total_deals: deals.count,
        won_deals: deals.select { |d| d.status == 'won' }.count,
        lost_deals: deals.select { |d| d.status == 'lost' }.count,
        total_revenue_cents: deals.select { |d| d.status == 'won' }.sum(&:value_cents)
      }
    end

    def fetch_deals
      return [] unless @resource.respond_to?(:deals)
      
      @resource.deals.order(created_at: :desc).limit(5).map do |deal|
        JrcCrm::DealSerializer.new(deal).as_json
      end
    end

    def fetch_proposals
      return [] unless @resource.respond_to?(:proposals)
      
      @resource.proposals.order(created_at: :desc).limit(5).map do |proposal|
        JrcCrm::ProposalSerializer.new(proposal).as_json
      end
    end

    def fetch_activities
      return [] unless @resource.respond_to?(:activities)
      
      @resource.activities.order(created_at: :desc).limit(5).map do |activity|
        JrcCrm::ActivitySerializer.new(activity).as_json
      end
    end

    def fetch_conversations
      return [] unless @resource.respond_to?(:conversations)
      
      @resource.conversations.order(created_at: :desc).limit(5).map do |conversation|
        {
          id: conversation.id,
          status: conversation.status,
          inbox_id: conversation.inbox_id,
          created_at: conversation.created_at
        }
      end
    end
  end
end
