# == Schema Information
#
# Table name: jrc_campaign_events
#
#  id           :bigint           not null, primary key
#  event_type   :string           not null
#  occurred_at  :datetime         not null
#  payload      :jsonb            not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  campaign_id  :bigint           not null
#  execution_id :bigint
#  recipient_id :bigint
#
# Indexes
#
#  index_jrc_campaign_events_on_campaign_id                 (campaign_id)
#  index_jrc_campaign_events_on_campaign_id_and_event_type  (campaign_id,event_type)
#  index_jrc_campaign_events_on_execution_id                (execution_id)
#  index_jrc_campaign_events_on_recipient_id                (recipient_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => jrc_campaigns.id)
#  fk_rails_...  (execution_id => jrc_campaign_executions.id)
#  fk_rails_...  (recipient_id => jrc_campaign_recipients.id)
#
class JrcCampaigns::Event < ApplicationRecord
  self.table_name = 'jrc_campaign_events'

  belongs_to :campaign, class_name: 'JrcCampaigns::Campaign'
  belongs_to :execution, class_name: 'JrcCampaigns::Execution', optional: true
  belongs_to :recipient, class_name: 'JrcCampaigns::Recipient', optional: true

  validates :event_type, :occurred_at, presence: true
end
