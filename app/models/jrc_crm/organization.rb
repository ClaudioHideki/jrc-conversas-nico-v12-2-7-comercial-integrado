# == Schema Information
#
# Table name: jrc_crm_organizations
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  custom_attributes :jsonb
#  description       :text
#  domain            :string
#  name              :string           not null
#  phone             :string
#  website           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#  owner_id          :integer
#
# Indexes
#
#  index_jrc_crm_organizations_on_account_id  (account_id)
#  index_jrc_crm_organizations_on_active      (active)
#  index_jrc_crm_organizations_on_name        (name)
#  index_jrc_crm_organizations_on_owner_id    (owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (owner_id => users.id)
#
module JrcCrm
  class Organization < ApplicationRecord
    self.table_name = 'jrc_crm_organizations'
    belongs_to :account
    belongs_to :owner, class_name: 'User', optional: true
    has_many :deals, class_name: 'JrcCrm::Deal', foreign_key: :organization_id, dependent: :nullify
    has_many :activities, class_name: 'JrcCrm::Activity', foreign_key: :organization_id, dependent: :nullify

    validates :name, presence: true
    validates :account_id, presence: true

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:name) }
    scope :search_by_name, ->(q) { where('name ILIKE ?', "%#{q}%") if q.present? }
  end
end
