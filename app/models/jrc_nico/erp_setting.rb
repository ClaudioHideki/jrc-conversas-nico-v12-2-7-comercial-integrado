# == Schema Information
#
# Table name: jrc_nico_erp_settings
#
#  id                  :bigint           not null, primary key
#  mode                :string           default("off"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  operator_company_id :string
#  requester_user_id   :string
#
# Indexes
#
#  index_jrc_nico_erp_settings_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class JrcNico::ErpSetting < ApplicationRecord
  self.table_name = 'jrc_nico_erp_settings'
  belongs_to :account
  validates :mode, inclusion: { in: %w[off fixture live] }
  validates :operator_company_id, :requester_user_id, format: { with: /\A[1-9]\d{0,12}\z/ }, allow_blank: true
end
