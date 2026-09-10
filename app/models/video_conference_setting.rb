# == Schema Information
#
# Table name: video_conference_settings
#
#  id                 :bigint           not null, primary key
#  moderator_password :text
#  moderator_url      :text
#  spectator_password :text
#  spectator_url      :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_video_conference_settings_on_account_id              (account_id)
#  index_video_conference_settings_on_account_id_and_user_id  (account_id,user_id) UNIQUE
#  index_video_conference_settings_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class VideoConferenceSetting < ApplicationRecord
  belongs_to :account
  belongs_to :user

  encrypts :moderator_password
  encrypts :spectator_password

  validates :user_id, uniqueness: { scope: :account_id }
  validate :user_belongs_to_account
  validate :valid_conference_urls

  def configured?
    moderator_url.present? || spectator_url.present?
  end

  private

  def user_belongs_to_account
    return if account&.users&.exists?(id: user_id)

    errors.add(:user, 'não pertence à conta')
  end

  def valid_conference_urls
    %i[moderator_url spectator_url].each do |attribute|
      value = public_send(attribute)
      next if value.blank?

      uri = URI.parse(value)
      errors.add(attribute, 'deve ser uma URL HTTPS válida') unless uri.is_a?(URI::HTTPS) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(attribute, 'deve ser uma URL HTTPS válida')
    end
  end
end
