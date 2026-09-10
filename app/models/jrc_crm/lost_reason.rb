# == Schema Information
#
# Table name: jrc_crm_lost_reasons
#
#  id                          :bigint           not null, primary key
#  active                      :boolean          default(TRUE), not null
#  name                        :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :integer          not null
#  legacy_sales_loss_reason_id :bigint
#
# Indexes
#
#  idx_jrc_crm_reasons_legacy_sales                   (account_id,legacy_sales_loss_reason_id) UNIQUE WHERE (legacy_sales_loss_reason_id IS NOT NULL)
#  index_jrc_crm_lost_reasons_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
module JrcCrm
  class LostReason < ApplicationRecord
    self.table_name = 'jrc_crm_lost_reasons'
    
    belongs_to :account
    has_many :deals
    
    validates :name, presence: true
    validates :name, uniqueness: { scope: :account_id }
    
    scope :active, -> { where(active: true) }
  end
end
