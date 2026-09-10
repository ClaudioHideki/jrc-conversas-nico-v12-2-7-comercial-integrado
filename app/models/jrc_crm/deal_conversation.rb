# == Schema Information
#
# Table name: jrc_crm_deal_conversations
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :integer          not null
#  conversation_id :integer          not null
#  created_by_id   :integer
#  deal_id         :bigint           not null
#
# Indexes
#
#  idx_jrc_crm_deal_conversations_uniq                  (deal_id,conversation_id) UNIQUE
#  index_jrc_crm_deal_conversations_on_account_id       (account_id)
#  index_jrc_crm_deal_conversations_on_conversation_id  (conversation_id)
#  index_jrc_crm_deal_conversations_on_deal_id          (deal_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (deal_id => jrc_crm_deals.id)
#
module JrcCrm
  class DealConversation < ApplicationRecord
    self.table_name = 'jrc_crm_deal_conversations'
    belongs_to :account
    belongs_to :deal, class_name: 'JrcCrm::Deal'
    belongs_to :conversation, class_name: 'Conversation'
    belongs_to :created_by, class_name: 'User', foreign_key: :created_by_id, optional: true

    validates :account_id, :deal_id, :conversation_id, presence: true
    validates :conversation_id, uniqueness: { scope: :deal_id, message: 'already linked to this deal' }
    validate :records_belong_to_account

    scope :recent, -> { order(created_at: :desc) }

    private

    def records_belong_to_account
      errors.add(:deal, 'must belong to account') if deal && deal.account_id != account_id
      errors.add(:conversation, 'must belong to account') if conversation && conversation.account_id != account_id
    end
  end
end
