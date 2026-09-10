require 'rails_helper'

RSpec.describe Hodupbx::CallHistoryService do
  subject(:service) do
    described_class.new(
      integration: integration,
      extension: '1110',
      start_date: Date.new(2026, 8, 1),
      end_date: Date.new(2026, 8, 6)
    )
  end

  let(:integration) { build(:telephony_integration) }
  let(:response) { instance_double(HTTParty::Response, success?: true, code: 200, parsed_response: payload) }
  let(:payload) do
    {
      'status' => 'SUCCESS',
      'data' => [
        {
          'callid' => '52635714',
          'unique_token' => 'unique-id',
          'call_direction' => 'OUTBOUND',
          'caller' => '1110',
          'caller_name' => 'Agente',
          'callee' => '11930202542',
          'callee_name' => '',
          'start_date' => '05-08-2026 10:29:58',
          'answer_time' => '05-08-2026 10:30:07',
          'end_date' => '05-08-2026 10:30:33',
          'call_sec' => '35',
          'answer_sec' => '26',
          'call_status' => 'Answered',
          'hangup_by' => 'CALLEE',
          'hangup_reason' => 'NORMAL_CLEARING',
          'call_rec_path' => 'https://portal-cloud.jrcpabx.com.br/recording.wav'
        }
      ]
    }
  end

  before do
    allow(HTTParty).to receive(:post).and_return(response)
  end

  it 'uses POST with converted dates, tenant token and agent extension' do
    service.call

    expect(HTTParty).to have_received(:post).with(
      'https://portal-cloud.jrcpabx.com.br/hodupbx_api/v1.4/api/info/01-08-2026/06-08-2026/TENANT/callLog',
      hash_including(body: { token_id: 'protected-tenant-token', number: '1110' }.to_json, timeout: 20)
    )
  end

  it 'normalizes the provider response' do
    call = service.call[:calls].first

    expect(call).to include(
      id: '52635714', direction: 'outbound', external_number: '11930202542', status: 'answered',
      total_duration_seconds: 35, talk_duration_seconds: 26
    )
    expect(call[:recording_url]).to eq('https://portal-cloud.jrcpabx.com.br/recording.wav')
  end

  it 'normalizes sentinel dates and missing recordings to nil' do
    payload['data'][0]['answer_time'] = '00-00-0000 00:00:00'
    payload['data'][0]['call_rec_path'] = '-'

    call = service.call[:calls].first
    expect(call[:answered_at]).to be_nil
    expect(call[:recording_url]).to be_nil
  end

  it 'returns a safe invalid credentials error for HTTP 412' do
    allow(response).to receive_messages(success?: false, code: 412)

    expect { service.call }.to raise_error(described_class::Error) do |error|
      expect(error.code).to eq(:invalid_credentials)
    end
  end

  it 'returns an empty list when the PBX has no calls for the selected period' do
    empty_payload = { 'status' => 'ERROR', 'message' => 'Requested Call Log Details Not Found.' }
    allow(response).to receive_messages(success?: false, code: 411, parsed_response: empty_payload)

    expect(service.call).to eq(count: 0, calls: [])
  end

  it 'returns a safe invalid response error for non-JSON payloads' do
    allow(response).to receive(:parsed_response).and_return('<html>error</html>')

    expect { service.call }.to raise_error(described_class::Error) do |error|
      expect(error.code).to eq(:invalid_response)
    end
  end

  it 'does not query when history is disabled' do
    integration.history_enabled = false

    expect { service.call }.to raise_error(described_class::Error) do |error|
      expect(error.code).to eq(:history_disabled)
    end
    expect(HTTParty).not_to have_received(:post)
  end
end
