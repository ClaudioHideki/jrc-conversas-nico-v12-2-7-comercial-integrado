class JrcCampaigns::EventLogger
  def self.call(campaign:, event_type:, execution: nil, recipient: nil, payload: {})
    JrcCampaigns::Event.create!(
      campaign: campaign,
      execution: execution,
      recipient: recipient,
      event_type: event_type,
      payload: payload,
      occurred_at: Time.current
    )
  end
end
