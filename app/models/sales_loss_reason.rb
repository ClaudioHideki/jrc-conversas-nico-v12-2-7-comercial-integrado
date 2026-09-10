# == Schema Information
#
# Table name: sales_loss_reasons
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#
# Indexes
#
#  index_sales_loss_reasons_on_account_id           (account_id)
#  index_sales_loss_reasons_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class SalesLossReason < ApplicationRecord
  belongs_to :account
  has_many :sales_opportunities, foreign_key: :loss_reason_id, dependent: :restrict_with_error, inverse_of: :loss_reason

  validates :name, presence: true, uniqueness: { scope: :account_id }
end
