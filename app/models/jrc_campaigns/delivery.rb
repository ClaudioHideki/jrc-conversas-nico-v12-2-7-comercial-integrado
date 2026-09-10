# == Schema Information
#
# Table name: jrc_campaign_deliveries
#
#  id            :bigint           not null, primary key
#  delivered_at  :datetime
#  error_message :text
#  failed_at     :datetime
#  metadata      :jsonb            not null
#  read_at       :datetime
#  sent_at       :datetime
#  status        :string           default("queued"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  external_id   :string
#  inbox_id      :integer          not null
#  recipient_id  :bigint           not null
#  step_id       :bigint           not null
#
# Indexes
#
#  index_jrc_campaign_deliveries_on_external_id               (external_id) UNIQUE WHERE (external_id IS NOT NULL)
#  index_jrc_campaign_deliveries_on_inbox_id                  (inbox_id)
#  index_jrc_campaign_deliveries_on_recipient_id              (recipient_id)
#  index_jrc_campaign_deliveries_on_recipient_id_and_step_id  (recipient_id,step_id) UNIQUE
#  index_jrc_campaign_deliveries_on_step_id                   (step_id)
#
# Foreign Keys
#
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (recipient_id => jrc_campaign_recipients.id)
#  fk_rails_...  (step_id => jrc_campaign_steps.id)
#
class JrcCampaigns::Delivery < ApplicationRecord
  self.table_name = 'jrc_campaign_deliveries'

  STATUSES = %w[queued sending sent delivered read failed skipped unknown].freeze

  enum :status, STATUSES.index_with(&:itself)

  belongs_to :recipient, class_name: 'JrcCampaigns::Recipient'
  belongs_to :step, class_name: 'JrcCampaigns::Step'
  belongs_to :inbox

  validates :status, inclusion: { in: STATUSES }
  validates :step_id, uniqueness: { scope: :recipient_id }
end
