# == Schema Information
#
# Table name: jrc_campaign_blacklists
#
#  id            :bigint           not null, primary key
#  phone_number  :string           not null
#  reason        :string
#  source        :string           default("manual"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :integer          not null
#  created_by_id :integer
#
# Indexes
#
#  index_jrc_campaign_blacklists_on_account_id                   (account_id)
#  index_jrc_campaign_blacklists_on_account_id_and_phone_number  (account_id,phone_number) UNIQUE
#  index_jrc_campaign_blacklists_on_created_by_id                (created_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id)
#
class JrcCampaigns::Blacklist < ApplicationRecord
  self.table_name = 'jrc_campaign_blacklists'

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true

  validates :phone_number, presence: true, uniqueness: { scope: :account_id }
  before_validation :normalize_phone_number

  private

  def normalize_phone_number
    self.phone_number = JrcCampaigns::PhoneNormalizer.call(phone_number)
  end
end
