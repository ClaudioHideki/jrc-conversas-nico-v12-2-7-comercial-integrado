class JrcCampaigns::LaunchJob < ApplicationJob
  queue_as :low

  def perform(campaign_id, scheduled_for = nil)
    campaign = JrcCampaigns::Campaign.find_by(id: campaign_id)
    return unless campaign
    return if campaign.canceled? || campaign.paused? || campaign.completed?
    return if stale_schedule?(campaign, scheduled_for)

    if campaign.scheduled? && campaign.scheduled_at&.future?
      self.class.set(wait_until: campaign.scheduled_at).perform_later(campaign.id, campaign.scheduled_at.to_i)
      return
    end

    JrcCampaigns::LaunchService.new(campaign).perform
  end

  private

  def stale_schedule?(campaign, scheduled_for)
    scheduled_for.present? && campaign.scheduled_at.to_i != scheduled_for.to_i
  end
end
