require 'rails_helper'

RSpec.describe 'JRC Broker inbox metadata', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:channel_api, account: account, webhook_url: 'https://broker.example.test/callback/synthetic-secret').inbox }

  around do |example|
    with_modified_env(JRC_BROKER_ENABLED: 'true') { example.run }
  end

  it 'exposes only a confirmed binding indicator to assigned agents, independent of arbitrary attributes' do
    account.enable_features!('jrc_broker')
    create(:inbox_member, inbox: inbox, user: agent)
    inbox.channel.update!(additional_attributes: { jrc_broker: true })
    get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}", headers: agent.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['jrc_broker_bound']).to be(false)
    JrcBrokerIntegration.create!(account: account, broker_origin: 'https://broker.example.test', organization_id: SecureRandom.uuid,
                                 destination_revision: 1, encrypted_control_key: 'synthetic-ciphertext')
    JrcBrokerInboxBinding.create!(account: account, inbox: inbox, integration_id: SecureRandom.uuid, instance_id: SecureRandom.uuid)
    get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}", headers: agent.create_new_auth_token
    expect(response.parsed_body['jrc_broker_bound']).to be(true)
    expect(response.body).not_to include('synthetic-secret', 'synthetic-ciphertext')
    account.disable_features!('jrc_broker')
    get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}", headers: agent.create_new_auth_token
    expect(response.parsed_body['jrc_broker_bound']).to be(false)
  end
end
