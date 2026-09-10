# == Schema Information
#
# Table name: jrc_crm_pipelines
#
#  id                       :bigint           not null, primary key
#  active                   :boolean          default(TRUE), not null
#  key                      :string           not null
#  name                     :string           not null
#  position                 :integer          not null
#  settings                 :jsonb            not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :integer          not null
#  legacy_sales_pipeline_id :bigint
#
# Indexes
#
#  idx_jrc_crm_pipelines_legacy_sales             (account_id,legacy_sales_pipeline_id) UNIQUE WHERE (legacy_sales_pipeline_id IS NOT NULL)
#  index_jrc_crm_pipelines_on_account_id_and_key  (account_id,key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
module JrcCrm
  class Pipeline < ApplicationRecord
    self.table_name = 'jrc_crm_pipelines'
    
    belongs_to :account
    has_many :stages, -> { order(:position) }, dependent: :destroy
    has_many :deals
    
    validates :name, :key, presence: true
    validates :key, uniqueness: { scope: :account_id }
    validates :position, numericality: { greater_than: 0 }
    
    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position) }
    
    before_create :set_position
    
    private
    
    def set_position
      return if position.present?
      max_position = self.class.where(account_id: account_id).maximum(:position) || 0
      self.position = max_position + 1
    end
  end
end
