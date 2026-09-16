require 'rails_helper'

RSpec.describe JrcBroker::Client do
  let(:origin) { 'https://broker.example.test' }
  let(:client) { described_class.new(origin: origin, token: 'synthetic-control-token', actor_id: 42) }
  let(:connection_id) { SecureRandom.uuid }

  around do |example|
    with_modified_env(JRC_BROKER_ALLOWED_ORIGINS: origin) { example.run }
  end

  it 'uses the scoped header and server actor, propagates idempotency, and keeps credentials out of URL/body' do
    stub = stub_request(:post, "#{origin}/v1/integrations/chatwoot/control/connections/#{connection_id}/pair")
           .with(headers: { 'X-JRC-API-Key' => 'synthetic-control-token', 'X-JRC-External-Actor' => '42',
                            'Idempotency-Key' => 'synthetic-intent-1' }, body: '{}')
           .to_return(status: 200, body: { action: { type: 'NONE', reason: 'ALREADY_CONNECTED' } }.to_json)
    expect(client.pair(connection_id, key: 'synthetic-intent-1')).to include('action')
    expect(stub).to have_been_requested.once
  end

  it 'rejects redirects and never forwards the credential to the destination' do
    stub_request(:get, "#{origin}/v1/integrations/chatwoot/control/context").to_return(status: 302,
                                                                                       headers: { Location: 'https://attacker.example.test' })
    expect { client.context }.to raise_error(described_class::Error, 'JRC_BROKER_UNAVAILABLE')
    expect(a_request(:get, 'https://attacker.example.test')).not_to have_been_made
  end

  it 'sanitizes remote failures and rejects path injection before HTTP' do
    stub_request(:get, "#{origin}/v1/integrations/chatwoot/control/context").to_return(status: 403, body: 'secret credential synthetic-control-token')
    expect { client.context }.to raise_error(described_class::Error, 'JRC_BROKER_FORBIDDEN')
    expect { client.status('../context') }.to raise_error(described_class::Error, 'JRC_BROKER_INVALID_REQUEST')
  end

  it 'treats timeout after a mutation as uncertain without an automatic retry' do
    stub = stub_request(:post, "#{origin}/v1/integrations/chatwoot/control/onboarding").to_timeout
    expect { client.start_onboarding({}, key: 'synthetic-intent-2') }.to raise_error(described_class::Error, 'JRC_BROKER_UNAVAILABLE')
    expect(stub).to have_been_requested.once
  end

  it 'rejects empty and header-injected credentials and never prints the credential' do
    [nil, '', "unsafe\r\nInjected: value"].each do |token|
      expect { described_class.new(origin: origin, token: token, actor_id: 42) }
        .to raise_error(JrcBroker::Configuration::InvalidConfiguration)
    end
    expect(client.inspect).not_to include('synthetic-control-token')
  end
end
