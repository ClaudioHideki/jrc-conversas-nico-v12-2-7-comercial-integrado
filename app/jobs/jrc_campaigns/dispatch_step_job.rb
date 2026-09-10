class JrcCampaigns::DispatchStepJob < ApplicationJob
  queue_as :low

  def perform(recipient_id, step_id)
    recipient = JrcCampaigns::Recipient.find_by(id: recipient_id)
    return unless recipient

    step = recipient.campaign.steps.find_by(id: step_id)
    return unless step

    JrcCampaigns::DispatchStepService.new(recipient: recipient, step: step).perform
  end
end
