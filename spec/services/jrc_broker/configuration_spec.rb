require 'rails_helper'

RSpec.describe JrcBroker::Configuration do
  let(:account) { create(:account) }
  let(:organization_id) { SecureRandom.uuid }
  let(:client) { double('Broker client') }

  around do |example|
    with_modified_env(JRC_BROKER_ENABLED: 'true', JRC_BROKER_ALLOWED_ORIGINS: 'https://broker.example.test',
                      JRC_BROKER_CREDENTIAL_KEY: Base64.strict_encode64('k' * 32), FRONTEND_URL: 'https://chatwoot.example.test') { example.run }
  end

  it 'does not require a key while disabled and fails closed on invalid enabled configuration' do
    with_modified_env(JRC_BROKER_ENABLED: 'false', JRC_BROKER_CREDENTIAL_KEY: nil) { expect(described_class.enabled?).to be(false) }
    with_modified_env(JRC_BROKER_CREDENTIAL_KEY: 'invalid') do
      expect { described_class.credential_store }.to raise_error(JrcBroker::CredentialStore::InvalidCredential)
    end
    expect { described_class.allowed_origin!('https://attacker.example.test') }.to raise_error(JrcBroker::Configuration::InvalidConfiguration)
    expect { described_class.allowed_origin!('https://broker.example.test@attacker.example.test') }.to raise_error(JrcBroker::Configuration::InvalidConfiguration)
  end

  it 'persists only after the authenticated context matches this account, organization and Chatwoot origin' do
    context = { 'organizationId' => organization_id, 'accountId' => account.id, 'chatwootOrigin' => 'https://chatwoot.example.test',
                'destinationRevision' => 1, 'capabilities' => {} }
    allow(client).to receive(:context).and_return(context.merge('accountId' => account.id + 1))
    expect do
      described_class.configure!(account: account, origin: 'https://broker.example.test', organization_id: organization_id,
                                 token: 'synthetic-control', client: client)
    end.to raise_error(JrcBroker::Configuration::InvalidConfiguration)
    expect(JrcBrokerIntegration.where(account: account)).not_to exist
    allow(client).to receive(:context).and_return(context)
    saved = described_class.configure!(account: account, origin: 'https://broker.example.test', organization_id: organization_id,
                                      token: 'synthetic-control', client: client)
    expect(described_class.credential_store.decrypt(account_id: account.id, ciphertext: saved.encrypted_control_key)).to eq('synthetic-control')
    expect(saved.organization_id).to eq(organization_id)
  end
end
