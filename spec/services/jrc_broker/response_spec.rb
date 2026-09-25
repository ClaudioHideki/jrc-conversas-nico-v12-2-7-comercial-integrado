require 'rails_helper'

RSpec.describe JrcBroker::Response do
  it 'rejects wrong encoding, missing PNG data prefix and arbitrary NONE reasons' do
    png = Base64.strict_encode64("\x89PNG\r\n\x1a\n".b)
    [{ 'type' => 'QR_CODE', 'encoding' => 'SVG', 'value' => png },
     { 'type' => 'QR_CODE', 'encoding' => 'DATA_URL', 'value' => png },
     { 'type' => 'NONE', 'reason' => 'secret remote diagnostic' }].each do |action|
      expect { described_class.action(action.merge('expiresAt' => 30.seconds.from_now.iso8601)) }
        .to raise_error(JrcBroker::Client::Error, 'JRC_BROKER_INVALID_RESPONSE')
    end
  end

  it 'does not release expired or malformed pairing actions' do
    ['not-a-date', 1.second.ago.iso8601].each do |expiry|
      expect { described_class.action('type' => 'PAIRING_CODE', 'code' => 'SYNTHETIC', 'expiresAt' => expiry) }
        .to raise_error(JrcBroker::Client::Error, 'JRC_BROKER_INVALID_RESPONSE')
    end
  end

  it 'accepts only the requested durable pairing operation and strips provider details' do
    operation_id = SecureRandom.uuid
    value = { 'operationId' => operation_id, 'state' => 'FAILED', 'reconciliationRequired' => true,
              'lastError' => 'provider secret', 'action' => nil }
    expect(described_class.pair_operation(value, operation_id))
      .to eq('operationId' => operation_id, 'state' => 'FAILED', 'reconciliationRequired' => true)
    expect { described_class.pair_operation(value.merge('operationId' => SecureRandom.uuid), operation_id) }
      .to raise_error(JrcBroker::Client::Error, 'JRC_BROKER_INVALID_RESPONSE')
    expect { described_class.pair_operation(value.merge('state' => 'QR_CODE'), operation_id) }
      .to raise_error(JrcBroker::Client::Error, 'JRC_BROKER_INVALID_RESPONSE')
    expect { described_class.pair_operation(value.merge('action' => { 'code' => 'NEVER-EXPOSE' }), operation_id) }
      .to raise_error(JrcBroker::Client::Error, 'JRC_BROKER_INVALID_RESPONSE')
  end

  it 'forwards only a valid, unexpired one-time pairing challenge on an operation read' do
    operation_id = SecureRandom.uuid
    action = { 'type' => 'PAIRING_CODE', 'code' => 'SYNTHETIC', 'expiresAt' => 30.seconds.from_now.iso8601 }
    payload = { 'operationId' => operation_id, 'state' => 'SUCCEEDED', 'reconciliationRequired' => false,
                'action' => action, 'providerSecret' => 'NEVER-EXPOSE' }
    result = described_class.pair_operation(payload, operation_id)
    expect(result['action']).to eq(action)
    expect(result).not_to have_key('providerSecret')
  end
end
