# == Schema Information
#
# Table name: jrc_crm_proposal_events
#
#  id          :bigint           not null, primary key
#  description :text
#  event_type  :string           not null
#  metadata    :jsonb
#  created_at  :datetime         not null
#  account_id  :integer          not null
#  proposal_id :bigint           not null
#  user_id     :integer
#
# Indexes
#
#  index_jrc_crm_proposal_events_on_account_id   (account_id)
#  index_jrc_crm_proposal_events_on_event_type   (event_type)
#  index_jrc_crm_proposal_events_on_proposal_id  (proposal_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (proposal_id => jrc_crm_proposals.id)
#  fk_rails_...  (user_id => users.id)
#
module JrcCrm
  class ProposalEvent < ApplicationRecord
    self.table_name = 'jrc_crm_proposal_events'
    
    belongs_to :account
    belongs_to :proposal, class_name: 'JrcCrm::Proposal'
    belongs_to :user, optional: true
    
    validates :event_type, :description, presence: true
    
    VALID_TYPES = %w[created updated approval_requested approval_updated sent viewed accepted rejected canceled revoked item_added item_removed pdf_generated].freeze
    validates :event_type, inclusion: { in: VALID_TYPES }
  end
end
