# == Schema Information
#
# Table name: sales_activities
#
#  id                   :bigint           not null, primary key
#  activity_type        :string           not null
#  completed_at         :datetime
#  notes                :text
#  scheduled_at         :datetime         not null
#  status               :string           default("scheduled"), not null
#  title                :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :integer          not null
#  contact_id           :integer          not null
#  owner_id             :integer          not null
#  sales_opportunity_id :bigint           not null
#
# Indexes
#
#  index_sales_activities_on_account_id                   (account_id)
#  index_sales_activities_on_account_id_and_owner_id      (account_id,owner_id)
#  index_sales_activities_on_account_id_and_scheduled_at  (account_id,scheduled_at)
#  index_sales_activities_on_account_id_and_status        (account_id,status)
#  index_sales_activities_on_contact_id                   (contact_id)
#  index_sales_activities_on_owner_id                     (owner_id)
#  index_sales_activities_on_sales_opportunity_id         (sales_opportunity_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (owner_id => users.id)
#  fk_rails_...  (sales_opportunity_id => sales_opportunities.id)
#
class SalesActivity < ApplicationRecord
  ACTIVITY_TYPES = %w[call meeting follow_up task demonstration].freeze
  STATUSES = %w[scheduled completed cancelled].freeze

  belongs_to :account
  belongs_to :sales_opportunity
  belongs_to :contact
  belongs_to :owner, class_name: 'User'

  validates :title, :scheduled_at, presence: true
  validates :activity_type, inclusion: { in: ACTIVITY_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validate :associations_belong_to_account

  def effective_status
    status == 'scheduled' && scheduled_at.past? ? 'overdue' : status
  end

  private

  def associations_belong_to_account
    errors.add(:sales_opportunity, 'must belong to the same account') if sales_opportunity && sales_opportunity.account_id != account_id
    errors.add(:contact, 'must belong to the same account') if contact && contact.account_id != account_id
    return if owner.blank? || owner.account_users.exists?(account_id: account_id)

    errors.add(:owner, 'must belong to the same account')
  end
end
