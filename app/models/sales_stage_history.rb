# == Schema Information
#
# Table name: sales_stage_histories
#
#  id                   :bigint           not null, primary key
#  changed_at           :datetime         not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :integer          not null
#  from_stage_id        :bigint
#  sales_opportunity_id :bigint           not null
#  to_stage_id          :bigint           not null
#  user_id              :integer          not null
#
# Indexes
#
#  index_sales_stage_histories_on_account_and_opportunity  (account_id,sales_opportunity_id)
#  index_sales_stage_histories_on_account_id               (account_id)
#  index_sales_stage_histories_on_from_stage_id            (from_stage_id)
#  index_sales_stage_histories_on_sales_opportunity_id     (sales_opportunity_id)
#  index_sales_stage_histories_on_to_stage_id              (to_stage_id)
#  index_sales_stage_histories_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (from_stage_id => sales_stages.id)
#  fk_rails_...  (sales_opportunity_id => sales_opportunities.id)
#  fk_rails_...  (to_stage_id => sales_stages.id)
#  fk_rails_...  (user_id => users.id)
#
class SalesStageHistory < ApplicationRecord
  belongs_to :account
  belongs_to :sales_opportunity
  belongs_to :from_stage, class_name: 'SalesStage', optional: true
  belongs_to :to_stage, class_name: 'SalesStage'
  belongs_to :user

  validates :changed_at, presence: true
  validate :associations_belong_to_account

  private

  def associations_belong_to_account
    [sales_opportunity, from_stage, to_stage].compact.each do |record|
      errors.add(:base, 'all records must belong to the same account') if record.account_id != account_id
    end
    errors.add(:user, 'must belong to the same account') if user && !user.account_users.exists?(account_id: account_id)
  end
end
