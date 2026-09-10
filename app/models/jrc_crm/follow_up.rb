# == Schema Information
#
# Table name: jrc_crm_follow_ups
#
#  id           :bigint           not null, primary key
#  completed_at :datetime
#  description  :text
#  due_at       :datetime
#  is_completed :boolean          default(FALSE)
#  title        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :integer          not null
#  deal_id      :bigint
#  lead_id      :bigint
#  user_id      :integer
#
# Indexes
#
#  index_jrc_crm_follow_ups_on_account_id  (account_id)
#  index_jrc_crm_follow_ups_on_deal_id     (deal_id)
#  index_jrc_crm_follow_ups_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (deal_id => jrc_crm_deals.id)
#  fk_rails_...  (lead_id => jrc_crm_leads.id)
#  fk_rails_...  (user_id => users.id)
#
module JrcCrm
  class FollowUp < ApplicationRecord
    self.table_name = 'jrc_crm_follow_ups'
    
    belongs_to :account
    belongs_to :user
    belongs_to :deal, class_name: 'JrcCrm::Deal', optional: true
    belongs_to :lead, class_name: 'JrcCrm::Lead', optional: true
    
    validates :title, :due_at, presence: true
    
    scope :pending, -> { where(is_completed: false) }
    scope :overdue, -> { pending.where('due_at < ?', Time.current) }
    scope :for_owner, ->(user_id) { where(user_id: user_id) }
  end
end
