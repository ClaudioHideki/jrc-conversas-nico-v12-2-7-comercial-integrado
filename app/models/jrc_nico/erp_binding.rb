# == Schema Information
#
# Table name: jrc_nico_erp_bindings
#
#  id                  :bigint           not null, primary key
#  cnpj                :string           not null
#  customer_name       :string           not null
#  enabled             :boolean          default(TRUE), not null
#  mode                :string           not null
#  version             :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  bemtevi_customer_id :string           not null
#  contact_id          :bigint           not null
#  helpdesk_company_id :string           not null
#  verified_by_id      :bigint           not null
#
# Indexes
#
#  index_jrc_nico_erp_bindings_on_account_id      (account_id)
#  index_jrc_nico_erp_bindings_on_contact_id      (contact_id)
#  index_jrc_nico_erp_bindings_on_verified_by_id  (verified_by_id)
#  nico_erp_contact_unique                        (account_id,contact_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (verified_by_id => users.id)
#
class JrcNico::ErpBinding < ApplicationRecord
  self.table_name = 'jrc_nico_erp_bindings'
  belongs_to :account
  belongs_to :contact
  belongs_to :verified_by, class_name: 'User'
  validates :cnpj, format: { with: /\A\d{14}\z/ }
  validates :bemtevi_customer_id, :helpdesk_company_id, format: { with: /\A[1-9]\d{0,12}\z/ }
  validates :mode, inclusion: { in: %w[fixture live] }
  validates :customer_name, :version, presence: true
  validate :contact_belongs_to_account

  def public_snapshot
    attributes.slice('id', 'cnpj', 'customer_name', 'bemtevi_customer_id', 'helpdesk_company_id', 'mode', 'enabled')
  end

  private

  def contact_belongs_to_account
    errors.add(:contact, :invalid) unless contact&.account_id == account_id
  end
end
