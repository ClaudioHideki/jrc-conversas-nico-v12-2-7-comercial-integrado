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
end
