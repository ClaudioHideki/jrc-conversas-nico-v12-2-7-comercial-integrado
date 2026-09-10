# == Schema Information
#
# Table name: jrc_campaign_steps
#
#  id                    :bigint           not null, primary key
#  body                  :text             default(""), not null
#  delay_after_seconds   :integer          default(0), not null
#  file_name             :string
#  follow_up_after_hours :integer
#  inbox_overrides       :jsonb            not null
#  kind                  :string           default("text"), not null
#  media_url             :string
#  only_if_no_reply      :boolean          default(FALSE), not null
#  position              :integer          default(0), not null
#  template_language     :string
#  template_name         :string
#  template_namespace    :string
#  template_params       :jsonb            not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  campaign_id           :bigint           not null
#
# Indexes
#
#  index_jrc_campaign_steps_on_campaign_id               (campaign_id)
#  index_jrc_campaign_steps_on_campaign_id_and_position  (campaign_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => jrc_campaigns.id)
#
class JrcCampaigns::Step < ApplicationRecord
  self.table_name = 'jrc_campaign_steps'

  KINDS = %w[text template image document video audio].freeze

  belongs_to :campaign, class_name: 'JrcCampaigns::Campaign'
  has_many :deliveries, class_name: 'JrcCampaigns::Delivery', dependent: :destroy

  validates :kind, inclusion: { in: KINDS }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validates :delay_after_seconds, numericality: { greater_than_or_equal_to: 0 }
  validates :follow_up_after_hours, numericality: { greater_than: 0 }, allow_nil: true
  validates :body, presence: true, if: -> { kind == 'text' }
  validates :template_name, :template_language, presence: true, if: -> { kind == 'template' }
  validates :media_url, presence: true, if: -> { %w[image document video audio].include?(kind) }
end
