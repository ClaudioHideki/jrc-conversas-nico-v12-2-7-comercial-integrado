# == Schema Information
#
# Table name: jrc_campaign_sanitized_lists
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  stats         :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :integer          not null
#  created_by_id :integer
#
# Indexes
#
#  index_jrc_campaign_sanitized_lists_on_account_id     (account_id)
#  index_jrc_campaign_sanitized_lists_on_created_by_id  (created_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id)
#
class JrcCampaigns::SanitizedList < ApplicationRecord
  self.table_name = 'jrc_campaign_sanitized_lists'

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :entries, class_name: 'JrcCampaigns::SanitizedEntry', dependent: :destroy

  validates :name, presence: true
end
