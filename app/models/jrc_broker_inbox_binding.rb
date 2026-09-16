class JrcBrokerInboxBinding < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, touch: true
  has_many :grants, class_name: 'JrcBrokerInboxGrant', foreign_key: :inbox_id, primary_key: :inbox_id, dependent: :destroy, inverse_of: :binding

  validates :inbox_id, uniqueness: true
  validates :integration_id, :instance_id, presence: true
  validates :integration_id, uniqueness: { scope: :account_id }
  validate :inbox_belongs_to_account

  private

  def inbox_belongs_to_account
    errors.add(:inbox, 'must be an API inbox in this account') unless inbox&.account_id == account_id && inbox&.channel_type == 'Channel::Api'
  end
end
