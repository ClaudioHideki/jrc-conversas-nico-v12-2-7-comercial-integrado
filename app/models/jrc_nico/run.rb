# == Schema Information
#
# Table name: jrc_nico_runs
#
#  id              :bigint           not null, primary key
#  agent_key       :string           default("nico"), not null
#  error_code      :string
#  fingerprint     :string           not null
#  finished_at     :datetime
#  message         :text             not null
#  reserved_tokens :integer          default(0), not null
#  result          :jsonb            not null
#  source_manifest :jsonb
#  started_at      :datetime
#  status          :string           default("queued"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  request_id      :uuid             not null
#  user_id         :bigint           not null
#
# Indexes
#
#  idx_nico_run_request                              (account_id,user_id,request_id) UNIQUE
#  index_jrc_nico_runs_on_account_id                 (account_id)
#  index_jrc_nico_runs_on_account_id_and_created_at  (account_id,created_at)
#  index_jrc_nico_runs_on_conversation_id            (conversation_id)
#  index_jrc_nico_runs_on_user_id                    (user_id)
#  nico_agent_history                                (account_id,agent_key,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class JrcNico::Run < ApplicationRecord
  self.table_name = 'jrc_nico_runs'

  belongs_to :account
  belongs_to :user
  belongs_to :conversation

  validates :message, presence: true, length: { maximum: 4000 }
  validates :request_id, format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i }
  validates :request_id, uniqueness: { scope: [:account_id, :user_id] }
  validates :status, inclusion: { in: %w[queued running completed failed cancelled] }
  validates :agent_key, inclusion: { in: JrcNico::AgentCatalog::KEYS }
  validate :same_account
  before_validation :set_fingerprint, on: :create

  scope :active, -> { where(status: %w[queued running]) }

  def self.fingerprint_for(conversation_id, message, agent_key = 'nico')
    input = [conversation_id, message]
    input << agent_key unless agent_key == 'nico'
    Digest::SHA256.hexdigest(input.to_json)
  end

  def snapshot
    readable = JrcNico::ResultAccess.allowed?(self)
    {
      id: id, account_id: account_id, conversation_id: conversation.display_id,
      agent_key: agent_key, agent_name: JrcNico::AgentCatalog.fetch(agent_key)[:name],
      allowed_actions: JrcNico::AgentCatalog.fetch(agent_key)[:actions],
      request_id: request_id, status: readable ? status : 'failed', message: message, result: readable ? result : {},
      error_code: readable ? error_code : 'source_access_revoked', created_at: created_at, started_at: started_at, finished_at: finished_at
    }
  end

  private

  def set_fingerprint
    self.fingerprint = self.class.fingerprint_for(conversation_id, message, agent_key)
  end

  def same_account
    errors.add(:conversation, 'must belong to account') if conversation && conversation.account_id != account_id
    errors.add(:user, 'must belong to account') if new_record? && user && account && !account.account_users.exists?(user_id: user_id)
  end
end
