FactoryBot.define do
  factory :telephony_integration do
    account
    provider { 'hodupbx' }
    history_enabled { true }
    cdr_base_url { 'https://portal-cloud.jrcpabx.com.br' }
    cdr_api_version { 'v1.4' }
    cdr_token { 'protected-tenant-token' }
    tenant_type { 'TENANT' }
    default_period_days { 7 }
  end
end
