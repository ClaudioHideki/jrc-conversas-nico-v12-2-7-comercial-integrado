module JrcCrm
  class RankingService
    def initialize(account:, period: nil, dimension: 'revenue_cents', pipeline_id: nil)
      @account = account
      @start_date = period ? Date.parse(period[:start_date]).beginning_of_day : 30.days.ago.beginning_of_day
      @end_date = period ? Date.parse(period[:end_date]).end_of_day : Date.current.end_of_day
      @dimension = dimension
      @pipeline_id = pipeline_id
    end

    def call
      users = @account.users
      ranking = users.map do |user|
        metrics = JrcCrm::MetricsCalculatorService.new(
          account: @account,
          pipeline_id: @pipeline_id,
          owner_id: user.id,
          start_date: @start_date,
          end_date: @end_date
        ).call
        
        {
          user: { id: user.id, name: user.name, email: user.email },
          metrics: metrics
        }
      end

      sort_dimension = @dimension.to_sym
      ranking.sort_by { |entry| entry[:metrics][sort_dimension] || 0 }.reverse
    end
  end
end
