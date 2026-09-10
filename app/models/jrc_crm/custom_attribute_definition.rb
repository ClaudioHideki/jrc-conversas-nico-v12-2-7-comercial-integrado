# == Schema Information
#
# Table name: jrc_crm_custom_attribute_definitions
#
#  id             :bigint           not null, primary key
#  active         :boolean          default(TRUE)
#  attribute_type :string
#  entity_type    :string
#  key            :string
#  name           :string
#  options        :jsonb
#  position       :integer
#  required       :boolean          default(FALSE)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :integer          not null
#
# Indexes
#
#  idx_jrc_crm_custom_attrs_account_entity                   (account_id,entity_type)
#  index_jrc_crm_custom_attribute_definitions_on_account_id  (account_id)
#
module JrcCrm
  class CustomAttributeDefinition < ApplicationRecord
    self.table_name = 'jrc_crm_custom_attribute_definitions'
    
    belongs_to :account
    
    validates :name, :key, :entity_type, :attribute_type, presence: true
    validates :key, uniqueness: { scope: [:account_id, :entity_type] }
    
    ENTITY_TYPES = %w[lead deal product]
    ATTRIBUTE_TYPES = %w[text textarea integer decimal boolean date datetime select multi_select]
    
    validates :entity_type, inclusion: { in: ENTITY_TYPES }
    validates :attribute_type, inclusion: { in: ATTRIBUTE_TYPES }
    
    scope :for_entity, ->(type) { active.where(entity_type: type).order(:position) }
    scope :active, -> { where(active: true) }
  end
end
