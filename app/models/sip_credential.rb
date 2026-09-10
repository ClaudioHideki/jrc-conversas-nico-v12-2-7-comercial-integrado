# == Schema Information
#
# Table name: sip_credentials
#
#  id                     :bigint           not null, primary key
#  call_history_extension :string
#  enabled                :boolean          default(TRUE), not null
#  extension              :string           not null
#  password               :text             not null
#  sip_domain             :string           not null
#  username               :string           not null
#  wss_server             :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  user_id                :bigint           not null
#
# Indexes
#
#  index_sip_credentials_on_account_id              (account_id)
#  index_sip_credentials_on_account_id_and_user_id  (account_id,user_id) UNIQUE
#  index_sip_credentials_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class SipCredential < ApplicationRecord
  belongs_to :account
  belongs_to :user

  encrypts :password

  validates :wss_server, :sip_domain, :extension, :username, :password, presence: true
  validates :user_id, uniqueness: { scope: :account_id }
  validate :user_belongs_to_account
  validate :secure_websocket_server

  def configured?
    enabled? && [wss_server, sip_domain, extension, username, password].all?(&:present?)
  end

  # `username` is the SIP authentication identity kept for compatibility with
  # existing records and clients. The PBX CDR lookup must never use it.
  alias_attribute :sip_username, :username

  def history_extension
    call_history_extension.presence || extension
  end

  private

  def user_belongs_to_account
    return if account&.users&.exists?(id: user_id)

    errors.add(:user, 'não pertence à conta')
  end

  def secure_websocket_server
    return if wss_server.blank? || wss_server.start_with?('wss://')

    errors.add(:wss_server, 'deve usar wss://')
  end
end
