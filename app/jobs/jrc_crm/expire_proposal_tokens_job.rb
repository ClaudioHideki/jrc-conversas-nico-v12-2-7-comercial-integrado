module JrcCrm
  class ExpireProposalTokensJob < ApplicationJob
    queue_as :jrc_crm_scheduled

    def perform
      JrcCrm::Proposal.where(status: ['draft', 'sent']).where('expires_at < ?', Time.current).find_each do |proposal|
        proposal.update!(status: 'canceled')
        JrcCrm::ProposalEvent.create!(
          proposal_id: proposal.id,
          event_type: 'canceled',
          actor_id: nil # System actor
        )
      end
    end
  end
end
