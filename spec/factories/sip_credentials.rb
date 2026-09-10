FactoryBot.define do
  factory :sip_credential do
    account
    user
    enabled { true }
    wss_server { 'wss://cloud.jrcpabx.com.br:7443' }
    sip_domain { 'cloud.jrcpabx.com.br' }
    extension { '1110' }
    call_history_extension { '1110' }
    username { '10081110' }
    password { 'sip-password' }
  end
end
