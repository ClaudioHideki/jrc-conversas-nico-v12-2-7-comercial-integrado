# == Schema Information
#
# Table name: jrc_campaign_executions
#
#  id              :bigint           not null, primary key
#  completed_at    :datetime
#  delivered_count :integer          default(0), not null
#  failed_count    :integer          default(0), not null
#  metadata        :jsonb            not null
#  read_count      :integer          default(0), not null
#  replied_count   :integer          default(0), not null
#  run_number      :integer          default(1), not null
#  sent_count      :integer          default(0), not null
#  started_at      :datetime
#  status          :string           default("queued"), not null
#  total_count     :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  campaign_id     :bigint           not null
#
# Indexes
#
#  index_jrc_campaign_executions_on_campaign_id                 (campaign_id)
#  index_jrc_campaign_executions_on_campaign_id_and_run_number  (campaign_id,run_number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => jrc_campaigns.id)
#
class JrcCampaigns::Execution < ApplicationRecord
  self.table_name = 'jrc_campaign_executions'

  STATUSES = %w[queued running completed failed canceled].freeze

  enum :status, STATUSES.index_with(&:itself)


  belongs_to :campaign, class_name: 'JrcCampaigns::Campaign'
  has_many :recipients, class_name: 'JrcCampaigns::Recipient', dependent: :destroy
  has_many :events, class_name: 'JrcCampaigns::Event', dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :run_number, numericality: { greater_than: 0 }, uniqueness: { scope: :campaign_id }

  def refresh_counters!
    update_columns( # rubocop:disable Rails/SkipsModelValidations
      total_count: recipients.count,
      sent_count: recipients.where.not(sent_at: nil).count,
      failed_count: recipients.where(status: 'failed').count,
      delivered_count: recipients.where.not(delivered_at: nil).count,
      read_count: recipients.where.not(read_at: nil).count,
      replied_count: recipients.where.not(replied_at: nil).count
    )
  end
end
