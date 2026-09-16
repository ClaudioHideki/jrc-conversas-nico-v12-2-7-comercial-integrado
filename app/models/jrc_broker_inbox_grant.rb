class JrcBrokerInboxGrant < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :user
  belongs_to :binding, class_name: 'JrcBrokerInboxBinding', foreign_key: :inbox_id, primary_key: :inbox_id, inverse_of: :grants

  validates :user_id, uniqueness: { scope: [:account_id, :inbox_id] }
  validate :current_memberships

  private

  def current_memberships
    valid = binding&.account_id == account_id && AccountUser.exists?(account_id: account_id, user_id: user_id) &&
            InboxMember.exists?(inbox_id: inbox_id, user_id: user_id)
    errors.add(:user, 'must belong to this account and inbox') unless valid
  end
end
