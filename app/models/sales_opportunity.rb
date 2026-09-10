# == Schema Information
#
# Table name: sales_opportunities
#
#  id                :bigint           not null, primary key
#  archived_at       :datetime
#  idempotency_key   :string
#  loss_notes        :text
#  lost_at           :datetime
#  notes             :text
#  product_name      :string
#  source_channel    :string
#  status            :string           default("open"), not null
#  temperature       :string           default("warm"), not null
#  title             :string           not null
#  value             :decimal(15, 2)
#  won_at            :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#  contact_id        :integer          not null
#  conversation_id   :integer
#  inbox_id          :integer
#  loss_reason_id    :bigint
#  owner_id          :integer          not null
#  sales_pipeline_id :bigint           not null
#  sales_stage_id    :bigint           not null
#  team_id           :bigint
#
# Indexes
#
#  index_sales_opportunities_on_account_id                      (account_id)
#  index_sales_opportunities_on_account_id_and_contact_id       (account_id,contact_id)
#  index_sales_opportunities_on_account_id_and_conversation_id  (account_id,conversation_id)
#  index_sales_opportunities_on_account_id_and_idempotency_key  (account_id,idempotency_key) UNIQUE WHERE (idempotency_key IS NOT NULL)
#  index_sales_opportunities_on_account_id_and_owner_id         (account_id,owner_id)
#  index_sales_opportunities_on_account_id_and_sales_stage_id   (account_id,sales_stage_id)
#  index_sales_opportunities_on_account_id_and_status           (account_id,status)
#  index_sales_opportunities_on_contact_id                      (contact_id)
#  index_sales_opportunities_on_conversation_id                 (conversation_id)
#  index_sales_opportunities_on_inbox_id                        (inbox_id)
#  index_sales_opportunities_on_loss_reason_id                  (loss_reason_id)
#  index_sales_opportunities_on_owner_id                        (owner_id)
#  index_sales_opportunities_on_sales_pipeline_id               (sales_pipeline_id)
#  index_sales_opportunities_on_sales_stage_id                  (sales_stage_id)
#  index_sales_opportunities_on_team_id                         (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (loss_reason_id => sales_loss_reasons.id)
#  fk_rails_...  (owner_id => users.id)
#  fk_rails_...  (sales_pipeline_id => sales_pipelines.id)
#  fk_rails_...  (sales_stage_id => sales_stages.id)
#  fk_rails_...  (team_id => teams.id)
#
class SalesOpportunity < ApplicationRecord
  TEMPERATURES = %w[cold warm hot very_hot].freeze
  STATUSES = %w[open won lost archived].freeze

  belongs_to :account
  belongs_to :sales_pipeline
  belongs_to :sales_stage
  belongs_to :contact
  belongs_to :conversation, optional: true
  belongs_to :inbox, optional: true
  belongs_to :team, optional: true
  belongs_to :owner, class_name: 'User'
  belongs_to :loss_reason, class_name: 'SalesLossReason', optional: true
  has_many :sales_activities, dependent: :destroy
  has_many :sales_stage_histories, dependent: :destroy

  validates :title, presence: true
  validates :temperature, inclusion: { in: TEMPERATURES }
  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, uniqueness: { scope: :account_id }, allow_nil: true
  validates :value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :associations_belong_to_account
  validate :loss_reason_required_when_lost

  scope :active, -> { where(archived_at: nil) }

  def next_activity
    activities = sales_activities.loaded? ? sales_activities.target : sales_activities.to_a
    activities.select { |activity| activity.status == 'scheduled' }.min_by(&:scheduled_at)
  end

  private

  def associations_belong_to_account
    {
      sales_pipeline: sales_pipeline,
      sales_stage: sales_stage,
      contact: contact,
      conversation: conversation,
      inbox: inbox,
      team: team,
      owner: owner,
      loss_reason: loss_reason
    }.each do |name, record|
      next if record.blank?

      record_account_id = name == :owner ? record.account_users.find_by(account_id: account_id)&.account_id : record.account_id
      errors.add(name, 'must belong to the same account') if record_account_id != account_id
    end
    if sales_stage && sales_pipeline && sales_stage.sales_pipeline_id != sales_pipeline_id
      errors.add(:sales_stage, 'must belong to the selected pipeline')
    end
    errors.add(:conversation, 'must belong to the selected contact') if conversation && conversation.contact_id != contact_id
  end

  def loss_reason_required_when_lost
    errors.add(:loss_reason, 'is required when the opportunity is lost') if status == 'lost' && loss_reason.blank?
  end
end
