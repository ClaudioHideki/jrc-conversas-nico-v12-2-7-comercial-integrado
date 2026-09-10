require 'rails_helper'

RSpec.describe Whatsapp::CallingConfigurationTestService do
  subject(:service) { described_class.new(configuration) }

  let(:account) { create(:account) }
  let(:waba_id) { '123456789' }
  let(:phone_number_id) { '123456789' }
  let(:access_token) { 'protected-token' }
  let(:configuration) do
    WhatsappCallingConfiguration.create!(
      account: account, enabled: true, waba_id: waba_id,
      phone_number_id: phone_number_id, access_token: access_token
    )
  end
  let(:graph_url) { 'https://graph.facebook.com/v22.0' }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token}" } }

  before do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              validate_provider_config: false, sync_templates: false)
  end

  describe '#perform' do
    before do
      stub_access_token_success
      stub_waba_success
      stub_phone_number_success(account_mode: account_mode)
      stub_calling_settings('DISABLED')
    end

    let(:account_mode) { 'SANDBOX' }

    it 'does not query the SANDBOX filter when the phone number appears in the regular listing' do
      stub_waba_phone_numbers([{ id: phone_number_id }])

      expect(service.perform).to be true
      expect(
        a_request(:get, "#{graph_url}/#{waba_id}/phone_numbers")
          .with(query: hash_including(filtering: described_class::SANDBOX_PHONE_NUMBER_FILTER))
      ).not_to have_been_made
    end

    context 'when the sandbox phone appears only in the filtered WABA listing' do
      before do
        stub_waba_phone_numbers([{ id: '999999999' }])
        stub_waba_phone_numbers([{ id: phone_number_id, account_mode: 'SANDBOX' }],
                                filtering: described_class::SANDBOX_PHONE_NUMBER_FILTER)
      end

      it 'uses the explicit Phone Number ID match without falling back to another number' do
        expect(service.perform).to be true
      end
    end

    context 'when the SANDBOX filter is not supported' do
      before do
        stub_waba_phone_numbers([{ id: '999999999' }])
        stub_sandbox_filter_unsupported
      end

      it 'accepts a public test number when direct phone access and local inbox relation are valid' do
        expect(service.perform).to be true
      end

      context 'when the direct phone response is not SANDBOX' do
        let(:account_mode) { 'LIVE' }

        it 'rejects the WABA and Phone Number ID combination' do
          expect { service.perform }
            .to raise_error(described_class::Error, 'O Phone Number ID informado não pertence ao WABA ID informado.')
        end
      end
    end

    context 'when the SANDBOX filtered listing returns an authentication error' do
      before do
        stub_waba_phone_numbers([{ id: '999999999' }])
        stub_request(:get, "#{graph_url}/#{waba_id}/phone_numbers")
          .with(
            headers: auth_headers,
            query: {
              fields: described_class::WABA_PHONE_NUMBER_FIELDS,
              limit: 100,
              filtering: described_class::SANDBOX_PHONE_NUMBER_FILTER
            }
          )
          .to_return(
            status: 401,
            body: { error: { message: 'Invalid OAuth access token.', code: 190 } }.to_json,
            headers: json_headers
          )
      end

      it 'continues to fail validation' do
        expect { service.perform }
          .to raise_error(described_class::Error, /Invalid OAuth access token/)
      end
    end

    context 'when the access token is invalid' do
      before do
        stub_request(:get, "#{graph_url}/me")
          .with(headers: auth_headers, query: { fields: 'id' })
          .to_return(
            status: 401,
            body: { error: { message: 'Invalid OAuth access token.' } }.to_json,
            headers: json_headers
          )
      end

      it 'surfaces the Meta error message' do
        expect { service.perform }
          .to raise_error(described_class::Error, /Access Token inválido ou expirado: Invalid OAuth access token/)
      end
    end

    context 'when the WABA cannot be accessed' do
      before do
        stub_request(:get, "#{graph_url}/#{waba_id}")
          .with(headers: auth_headers, query: { fields: described_class::WABA_FIELDS })
          .to_return(
            status: 403,
            body: { error: { message: 'Unsupported get request.' } }.to_json,
            headers: json_headers
          )
      end

      it 'fails at the WABA validation step' do
        expect { service.perform }
          .to raise_error(
            described_class::Error,
            /Não foi possível acessar o WABA ID informado: Unsupported get request/
          )
      end
    end

    context 'when the Phone Number ID cannot be accessed directly' do
      before do
        stub_request(:get, "#{graph_url}/#{phone_number_id}")
          .with(headers: auth_headers, query: { fields: described_class::PHONE_NUMBER_FIELDS })
          .to_return(
            status: 403,
            body: { error: { message: 'Phone number is not accessible.' } }.to_json,
            headers: json_headers
          )
      end

      it 'fails at the direct phone validation step' do
        expect { service.perform }
          .to raise_error(described_class::Error, /Phone number is not accessible/)
      end
    end

    context 'when Meta confirms the phone number belongs to another WABA' do
      let(:account_mode) { 'LIVE' }

      before do
        stub_waba_phone_numbers([{ id: '999999999' }])
        stub_waba_phone_numbers([], filtering: described_class::SANDBOX_PHONE_NUMBER_FILTER)
      end

      it 'rejects the combination instead of accepting the listed fallback number' do
        expect { service.perform }
          .to raise_error(described_class::Error, 'O Phone Number ID informado não pertence ao WABA ID informado.')
      end
    end

    context 'when the local WhatsApp Cloud inbox points to another WABA' do
      let(:waba_id) { '987654321' }

      before do
        stub_waba_phone_numbers([{ id: '999999999' }])
        stub_sandbox_filter_unsupported
      end

      it 'rejects the combination even for sandbox phone numbers' do
        expect { service.perform }
          .to raise_error(described_class::Error, 'A Caixa de Entrada WhatsApp Cloud associada usa outro WABA ID.')
      end
    end

    context 'when Meta does not return a Calling status' do
      before do
        stub_request(:get, "#{graph_url}/#{phone_number_id}/settings")
          .with(headers: auth_headers, query: { fields: 'calling' })
          .to_return(status: 200, body: { calling: {} }.to_json, headers: json_headers)
      end

      it 'does not mark the configuration as valid' do
        expect { service.perform }
          .to raise_error(described_class::Error, /não retornou o status de Calling/)
      end
    end
  end

  def stub_access_token_success
    stub_request(:get, "#{graph_url}/me")
      .with(headers: auth_headers, query: { fields: 'id' })
      .to_return(status: 200, body: { id: 'system-user-id' }.to_json, headers: json_headers)
  end

  def stub_waba_success
    stub_request(:get, "#{graph_url}/#{waba_id}")
      .with(headers: auth_headers, query: { fields: described_class::WABA_FIELDS })
      .to_return(status: 200, body: { id: waba_id }.to_json, headers: json_headers)
  end

  def stub_phone_number_success(account_mode:)
    stub_request(:get, "#{graph_url}/#{phone_number_id}")
      .with(headers: auth_headers, query: { fields: described_class::PHONE_NUMBER_FIELDS })
      .to_return(
        status: 200,
        body: {
          id: phone_number_id,
          display_phone_number: '15550783881',
          verified_name: 'JRC Test',
          code_verification_status: 'VERIFIED',
          account_mode: account_mode
        }.to_json,
        headers: json_headers
      )
  end

  def stub_waba_phone_numbers(phone_numbers, filtering: nil)
    query = { fields: described_class::WABA_PHONE_NUMBER_FIELDS, limit: 100 }
    query[:filtering] = filtering if filtering

    stub_request(:get, "#{graph_url}/#{waba_id}/phone_numbers")
      .with(headers: auth_headers, query: query)
      .to_return(status: 200, body: { data: phone_numbers }.to_json, headers: json_headers)
  end

  def stub_calling_settings(status)
    stub_request(:get, "#{graph_url}/#{phone_number_id}/settings")
      .with(headers: auth_headers, query: { fields: 'calling' })
      .to_return(status: 200, body: { calling: { status: status } }.to_json, headers: json_headers)
  end

  def stub_sandbox_filter_unsupported
    stub_request(:get, "#{graph_url}/#{waba_id}/phone_numbers")
      .with(
        headers: auth_headers,
        query: {
          fields: described_class::WABA_PHONE_NUMBER_FIELDS,
          limit: 100,
          filtering: described_class::SANDBOX_PHONE_NUMBER_FILTER
        }
      )
      .to_return(
        status: 400,
        body: { error: { message: 'Filtering by account_mode is not supported for this app.', code: 100 } }.to_json,
        headers: json_headers
      )
  end
end
