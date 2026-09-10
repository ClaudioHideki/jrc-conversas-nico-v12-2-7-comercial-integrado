# == Schema Information
#
# Table name: jrc_nico_proposals
#
#  id          :bigint           not null, primary key
#  approved_at :datetime
#  digest      :string           not null
#  expires_at  :datetime         not null
#  payload     :jsonb            not null
#  status      :string           default("pending"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  activity_id :bigint
#  request_id  :uuid             not null
#  run_id      :bigint           not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_jrc_nico_proposals_on_account_id   (account_id)
#  index_jrc_nico_proposals_on_activity_id  (activity_id)
#  index_jrc_nico_proposals_on_run_id       (run_id)
#  index_jrc_nico_proposals_on_user_id      (user_id)
#  nico_proposal_idempotency                (account_id,user_id,request_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (activity_id => jrc_crm_activities.id) ON DELETE => nullify
#  fk_rails_...  (run_id => jrc_nico_runs.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class JrcNico::Proposal < ApplicationRecord
  self.table_name = 'jrc_nico_proposals'
  belongs_to :account
  belongs_to :user
  belongs_to :run, class_name: 'JrcNico::Run'
  belongs_to :activity, class_name: 'JrcCrm::Activity', optional: true
  validates :request_id, format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i }

  def snapshot
    { id: id, run_id: run_id, payload: payload, digest: digest, status: status, activity_id: activity_id, deal_id: activity&.deal_id,
      expires_at: expires_at, approved_at: approved_at }
  end
end
