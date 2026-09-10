# == Schema Information
#
# Table name: jrc_ai_usage_events
#
#  id                   :bigint           not null, primary key
#  agent_key            :string           default("copilot"), not null
#  estimated_cost_cents :bigint           default(0), not null
#  feature              :string           default("assistant"), not null
#  input_tokens         :bigint           default(0), not null
#  metadata             :jsonb            not null
#  model                :string
#  output_tokens        :bigint           default(0), not null
#  total_tokens         :bigint           default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  provider_id          :bigint
#  user_id              :bigint
#
# Indexes
#
#  idx_jrc_ai_usage_by_agent                               (account_id,agent_key,created_at)
#  index_jrc_ai_usage_events_on_account_id                 (account_id)
#  index_jrc_ai_usage_events_on_account_id_and_created_at  (account_id,created_at)
#  index_jrc_ai_usage_events_on_provider_id                (provider_id)
#  index_jrc_ai_usage_events_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (provider_id => jrc_ai_providers.id)
#  fk_rails_...  (user_id => users.id)
#
module JrcAi
  class UsageEvent < ApplicationRecord
    self.table_name = 'jrc_ai_usage_events'

    belongs_to :account
    belongs_to :provider, class_name: 'JrcAi::Provider', optional: true
    belongs_to :user, optional: true

    validates :agent_key, :feature, presence: true
    validates :input_tokens, :output_tokens, :total_tokens, :estimated_cost_cents,
              numericality: { greater_than_or_equal_to: 0 }

    scope :today, -> { where(created_at: Time.current.all_day) }
    scope :current_month, -> { where(created_at: Time.current.beginning_of_month..Time.current.end_of_month) }
  end
end
