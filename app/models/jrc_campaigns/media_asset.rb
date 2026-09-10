# == Schema Information
#
# Table name: jrc_campaign_media_assets
#
#  id            :bigint           not null, primary key
#  kind          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :integer          not null
#  created_by_id :integer
#
# Indexes
#
#  index_jrc_campaign_media_assets_on_account_id     (account_id)
#  index_jrc_campaign_media_assets_on_created_by_id  (created_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id)
#
class JrcCampaigns::MediaAsset < ApplicationRecord
  self.table_name = 'jrc_campaign_media_assets'

  KINDS = %w[image document video audio].freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  has_one_attached :file

  validates :kind, inclusion: { in: KINDS }
  validates :file, presence: true
  validate :acceptable_file

  private

  def acceptable_file
    return unless file.attached?

    max_size_mb = GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', 40).to_i
    max_size_mb = 40 if max_size_mb <= 0
    errors.add(:file, 'excede o tamanho máximo permitido') if file.byte_size > max_size_mb.megabytes

    content_type = file.content_type.to_s
    matches_kind = case kind
                   when 'image' then content_type.start_with?('image/')
                   when 'video' then content_type.start_with?('video/')
                   when 'audio' then content_type.start_with?('audio/')
                   when 'document' then !content_type.start_with?('image/', 'video/', 'audio/')
                   else false
                   end
    errors.add(:file, 'não corresponde ao tipo de mídia selecionado') unless matches_kind
  end
end
