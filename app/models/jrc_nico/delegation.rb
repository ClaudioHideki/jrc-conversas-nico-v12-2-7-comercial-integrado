# == Schema Information
#
# Table name: jrc_nico_delegations
#
#  id              :bigint           not null, primary key
#  allow_crm       :boolean          default(FALSE), not null
#  expires_at      :datetime         not null
#  objective       :text             not null
#  reason          :string
#  status          :string           default("active"), not null
#  summary         :text
#  version         :integer          default(1), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  agent_bot_id    :bigint           not null
#  conversation_id :bigint           not null
#  last_message_id :bigint           default(0), not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_jrc_nico_delegations_on_account_id       (account_id)
#  index_jrc_nico_delegations_on_agent_bot_id     (agent_bot_id)
#  index_jrc_nico_delegations_on_conversation_id  (conversation_id) UNIQUE
#  index_jrc_nico_delegations_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (agent_bot_id => agent_bots.id)
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class JrcNico::Delegation < ApplicationRecord
  self.table_name = 'jrc_nico_delegations'
  belongs_to :account
  belongs_to :user
  belongs_to :conversation
  belongs_to :agent_bot
  has_many :turns, class_name: 'JrcNico::Turn', dependent: :destroy
  validates :objective, presence: true, length: { maximum: 2000 }
  validates :status, inclusion: { in: %w[active paused needs_human completed] }
  validate :valid_allowed_actions
  scope :active, -> { where(status: 'active').where('expires_at > ?', Time.current) }
  after_commit :enqueue_first_turn, on: [:create, :update]

  def enqueue_first_turn
    return unless status == 'active' && (previous_changes.key?('status') || previous_changes.key?('version'))

    JrcNico::CustomerTurnJob.set(wait: 2.seconds).perform_later(id)
    JrcNico::CustomerTurnJob.set(wait_until: expires_at).perform_later(id)
  end

  def live?
    status == 'active' && expires_at > Time.current
  end

  def valid_allowed_actions
    valid = allowed_actions.is_a?(Array) && (allowed_actions - JrcNico::DelegatedActions::GROUPS.keys).empty?
    errors.add(:allowed_actions, 'contém uma ação desconhecida') unless valid
  end

  def snapshot
    { id: id, conversation_id: conversation.display_id, contact_name: conversation.contact.name,
      status: live? ? 'active' : (status == 'active' ? 'paused' : status), objective: objective,
      summary: summary, reason: expires_at <= Time.current ? 'expired' : reason, expires_at: expires_at,
      allow_crm: allow_crm, allowed_actions: allowed_actions }
  end
end
