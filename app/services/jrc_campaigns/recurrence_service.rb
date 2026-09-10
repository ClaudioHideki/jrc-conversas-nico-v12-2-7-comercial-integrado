class JrcCampaigns::RecurrenceService
  def initialize(campaign)
    @campaign = campaign
  end

  def next_time
    config = campaign.recurrence_config.with_indifferent_access
    kind = config[:type].to_s
    return if kind.blank? || kind == 'none'

    base = campaign.last_execution_at || Time.current
    case kind
    when 'daily' then base + 1.day
    when 'weekly' then base + 1.week
    when 'monthly' then base + 1.month
    when 'custom'
      interval_days = config[:interval_days].to_i
      base + interval_days.days if interval_days.positive?
    end
  end

  private

  attr_reader :campaign
end
