# == Schema Information
#
# Table name: whatsapp_calling_configurations
#
#  id                   :bigint           not null, primary key
#  access_token         :text
#  configuration_status :string           default("not_configured"), not null
#  enabled              :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  phone_number_id      :string
#  waba_id              :string
#
# Indexes
#
#  index_whatsapp_calling_configurations_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class WhatsappCallingConfiguration < ApplicationRecord
  STATUSES = %w[not_configured configured error].freeze

  belongs_to :account

  encrypts :access_token

  validates :account_id, uniqueness: true
  validates :configuration_status, inclusion: { in: STATUSES }
  validates :waba_id, :phone_number_id, format: { with: /\A\d+\z/ }, allow_blank: true
  validates :waba_id, :phone_number_id, :access_token, presence: true, if: :enabled?

  before_validation :reset_configuration_status, if: :configuration_changed?

  def complete?
    waba_id.present? && phone_number_id.present? && access_token.present?
  end

  def ready?
    enabled? && complete? && configuration_status == 'configured'
  end

  private

  def configuration_changed?
    will_save_change_to_waba_id? || will_save_change_to_phone_number_id? ||
      will_save_change_to_access_token?
  end

  def reset_configuration_status
    self.configuration_status = 'not_configured'
  end
end
