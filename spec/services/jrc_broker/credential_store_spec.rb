require 'rails_helper'

RSpec.describe JrcBroker::CredentialStore do
  let(:store) { described_class.new(key: SecureRandom.random_bytes(32)) }

  it 'binds ciphertext to its account and rejects tampering or another key' do
    ciphertext = store.encrypt(account_id: 1, token: 'synthetic-control-token')
    expect(ciphertext).not_to include('synthetic-control-token')
    expect(store.decrypt(account_id: 1, ciphertext: ciphertext)).to eq('synthetic-control-token')
    expect { store.decrypt(account_id: 2, ciphertext: ciphertext) }.to raise_error(described_class::InvalidCredential)
    expect { store.decrypt(account_id: 1, ciphertext: "#{ciphertext}tampered") }.to raise_error(described_class::InvalidCredential)
    other = described_class.new(key: SecureRandom.random_bytes(32))
    expect { other.decrypt(account_id: 1, ciphertext: ciphertext) }.to raise_error(described_class::InvalidCredential)
  end

  it 'requires exactly 32 bytes and never accepts an empty credential' do
    expect { described_class.new(key: 'short') }.to raise_error(described_class::InvalidCredential)
    expect { store.encrypt(account_id: 1, token: '') }.to raise_error(described_class::InvalidCredential)
  end
end
