require 'rails_helper'

describe Whatsapp::Providers::WhatsappCloudService do
  subject(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  let(:whatsapp_channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  # Call-flow endpoints use the configured WHATSAPP_API_VERSION (fallback v22.0),
  # not the OSS v13.0 path locked for legacy /messages compatibility.
  let(:calls_url) { 'https://graph.facebook.com/v22.0/123456789/calls' }
  let(:messages_url) { 'https://graph.facebook.com/v22.0/123456789/messages' }
  let(:permissions_url) { 'https://graph.facebook.com/v22.0/123456789/call_permissions' }
  let(:settings_url) { 'https://graph.facebook.com/v22.0/123456789/settings' }
  let(:headers) { { 'Content-Type' => 'application/json' } }

  before do
    stub_request(:get, /message_templates/)
    configuration = WhatsappCallingConfiguration.create!(
      account: whatsapp_channel.account, enabled: true, configuration_status: 'configured', waba_id: '123456789',
      phone_number_id: whatsapp_channel.provider_config['phone_number_id'], access_token: 'protected-token'
    )
    configuration.update!(configuration_status: 'configured')
  end

  describe 'call action methods' do
    it 'POSTs the action body with the SDP answer and returns true on success' do
      stub_request(:post, calls_url)
        .with(body: { messaging_product: 'whatsapp', call_id: 'WACALL', action: 'pre_accept',
                      session: { sdp: 'sdp_answer', sdp_type: 'answer' } }.to_json)
        .to_return(status: 200, body: '{}', headers: headers)

      expect(service.pre_accept_call('WACALL', 'sdp_answer')).to be true
    end

    it 'returns false when Meta responds with a non-success status' do
      stub_request(:post, calls_url).to_return(status: 400, body: '{}', headers: headers)

      expect(service.reject_call('WACALL')).to be false
    end
  end

  describe '#send_call_permission_request' do
    it 'returns the parsed body on success' do
      stub_request(:post, messages_url)
        .with(body: hash_including(messaging_product: 'whatsapp', to: '15551234567', type: 'interactive'))
        .to_return(status: 200, body: { messages: [{ id: 'wamid' }] }.to_json, headers: headers)

      expect(service.send_call_permission_request('15551234567')).to eq('messages' => [{ 'id' => 'wamid' }])
    end
  end

  describe '#update_calling_status' do
    it 'updates and confirms the calling settings at Meta' do
      stub_request(:post, settings_url)
        .with(body: { calling: { status: 'ENABLED' } }.to_json)
        .to_return(status: 200, body: { success: true }.to_json, headers: headers)
      stub_request(:get, settings_url)
        .with(query: { fields: 'calling' })
        .to_return(status: 200, body: { calling: { status: 'ENABLED' } }.to_json, headers: headers)

      expect(service.update_calling_status('ENABLED')).to be true
    end

    it 'accepts lowercase status values returned by Meta projections' do
      stub_request(:post, settings_url)
        .with(body: { calling: { status: 'ENABLED' } }.to_json)
        .to_return(status: 200, body: { success: true }.to_json, headers: headers)
      stub_request(:get, settings_url)
        .with(query: { fields: 'calling' })
        .to_return(status: 200, body: { calling: { status: 'enabled' } }.to_json, headers: headers)

      expect(service.update_calling_status('ENABLED')).to be true
    end

    it 'raises when Meta accepts the write but does not confirm the requested status' do
      stub_request(:post, settings_url).to_return(status: 200, body: { success: true }.to_json, headers: headers)
      stub_request(:get, settings_url)
        .with(query: { fields: 'calling' })
        .to_return(status: 200, body: { calling: { status: 'DISABLED' } }.to_json, headers: headers)

      expect { service.update_calling_status('ENABLED') }
        .to raise_error('Meta did not confirm calling status ENABLED')
    end
  end

  describe '#call_permission' do
    it 'allows calling only when Meta exposes the start_call action' do
      stub_request(:get, permissions_url)
        .with(query: { user_wa_id: '15551234567' })
        .to_return(
          status: 200,
          body: {
            permission: { status: 'temporary', expiration_time: 1.hour.from_now.to_i },
            actions: [{ action_name: 'start_call', can_perform_action: true }]
          }.to_json,
          headers: headers
        )

      expect(service.call_permission('15551234567')).to include(
        status: 'approved', can_start_call: true, can_request_permission: false
      )
    end

    it 'returns a functional state when permission must be requested' do
      stub_request(:get, permissions_url)
        .with(query: { user_wa_id: '15551234567' }).to_return(
          status: 200,
          body: {
            permission: { status: 'no_permission' },
            actions: [{ action_name: 'send_call_permission_request', can_perform_action: true }]
          }.to_json,
          headers: headers
        )

      expect(service.call_permission('15551234567')).to include(
        status: 'permission_required', can_start_call: false, can_request_permission: true
      )
    end

    it 'preserves pending, denied, and expired as functional states' do
      {
        'pending' => 'permission_pending',
        'denied' => 'permission_denied',
        'expired' => 'permission_expired'
      }.each do |meta_status, expected_status|
        stub_request(:get, permissions_url)
          .with(query: { user_wa_id: '15551234567' }).to_return(
            status: 200,
            body: { permission: { status: meta_status }, actions: [] }.to_json,
            headers: headers
          )

        expect(service.call_permission('15551234567')[:status]).to eq(expected_status)
      end
    end

    it 'converts an invalid Meta token into a functional credential error' do
      stub_request(:get, permissions_url)
        .with(query: { user_wa_id: '15551234567' }).to_return(
          status: 401, body: { error: { code: 190 } }.to_json, headers: headers
        )

      expect { service.call_permission('15551234567') }
        .to raise_error(Voice::CallErrors::InvalidCallingCredential)
    end
  end

  describe '#initiate_call' do
    it 'returns the parsed body on success' do
      stub_request(:post, calls_url)
        .with(body: { messaging_product: 'whatsapp', to: '15551234567', action: 'connect',
                      session: { sdp: 'sdp_offer', sdp_type: 'offer' } }.to_json)
        .to_return(status: 200, body: { messages: [{ id: 'wacall_1' }] }.to_json, headers: headers)

      expect(service.initiate_call('15551234567', 'sdp_offer')).to eq('messages' => [{ 'id' => 'wacall_1' }])
    end

    it 'raises Voice::CallErrors::NoCallPermission when Meta returns error code 138006' do
      stub_request(:post, calls_url).to_return(
        status: 400,
        body: { error: { code: 138_006, error_user_msg: 'No call permission' } }.to_json,
        headers: headers
      )

      expect { service.initiate_call('15551234567', 'sdp_offer') }
        .to raise_error(Voice::CallErrors::NoCallPermission, 'No call permission')
    end

    it 'raises Voice::CallErrors::CallFailed with a fallback message when the error body is non-JSON' do
      stub_request(:post, calls_url).to_return(status: 502, body: '<html>502 Bad Gateway</html>',
                                               headers: { 'Content-Type' => 'text/html' })

      expect { service.initiate_call('15551234567', 'sdp_offer') }
        .to raise_error(Voice::CallErrors::CallFailed, 'Failed to initiate call')
    end
  end
end
