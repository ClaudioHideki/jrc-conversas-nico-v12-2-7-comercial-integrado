FactoryBot.define do
  factory :sales_pipeline do
    account
    sequence(:name) { |number| "Pipeline #{number}" }
    active { true }
  end

  factory :sales_stage do
    account
    sales_pipeline
    sequence(:name) { |number| "Stage #{number}" }
    sequence(:position)
    color { '#3B82F6' }
    stage_type { 'open' }
    active { true }
  end

  factory :sales_loss_reason do
    account
    sequence(:name) { |number| "Reason #{number}" }
    active { true }
  end

  factory :sales_opportunity do
    account
    sales_pipeline { association :sales_pipeline, account: account }
    sales_stage { association :sales_stage, account: account, sales_pipeline: sales_pipeline }
    contact { association :contact, account: account }
    owner { association :user, account: account }
    sequence(:title) { |number| "Opportunity #{number}" }
    temperature { 'warm' }
    status { 'open' }
  end

  factory :sales_activity do
    account
    sales_opportunity { association :sales_opportunity, account: account }
    contact { sales_opportunity.contact }
    owner { sales_opportunity.owner }
    activity_type { 'follow_up' }
    title { 'Customer follow-up' }
    scheduled_at { 1.day.from_now }
    status { 'scheduled' }
  end
end
