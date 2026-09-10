# == Schema Information
#
# Table name: sales_stages
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  color             :string           not null
#  name              :string           not null
#  position          :integer          not null
#  stage_type        :string           default("open"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#  sales_pipeline_id :bigint           not null
#
# Indexes
#
#  index_sales_stages_on_account_id                      (account_id)
#  index_sales_stages_on_sales_pipeline_id               (sales_pipeline_id)
#  index_sales_stages_on_sales_pipeline_id_and_name      (sales_pipeline_id,name) UNIQUE
#  index_sales_stages_on_sales_pipeline_id_and_position  (sales_pipeline_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (sales_pipeline_id => sales_pipelines.id)
#
class SalesStage < ApplicationRecord
  STAGE_TYPES = %w[open won lost].freeze

  belongs_to :account
  belongs_to :sales_pipeline
  has_many :sales_opportunities, dependent: :restrict_with_error

  validates :name, :position, :color, :stage_type, presence: true
  validates :name, uniqueness: { scope: :sales_pipeline_id }
  validates :position, uniqueness: { scope: :sales_pipeline_id }
  validates :stage_type, inclusion: { in: STAGE_TYPES }
  validate :pipeline_belongs_to_account

  private

  def pipeline_belongs_to_account
    errors.add(:sales_pipeline, 'must belong to the same account') if sales_pipeline && sales_pipeline.account_id != account_id
  end
end
