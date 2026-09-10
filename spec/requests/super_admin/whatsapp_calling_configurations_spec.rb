require 'rails_helper'

RSpec.describe 'Super Admin WhatsApp Calling configuration', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              validate_provider_config: false, sync_templates: false)
  end
  let(:configuration) do
    record = WhatsappCallingConfiguration.create!(
      account: account, enabled: true, configuration_status: 'configured', waba_id: '123456789',
      phone_number_id: channel.provider_config['phone_number_id'], access_token: 'protected-token'
    )
    record.update!(configuration_status: 'configured')
    record
  end

  before { sign_in(super_admin, scope: :super_admin) }

  it 'enables channel_voice after a valid configuration is activated' do
    configuration.update!(enabled: false)

    patch "/super_admin/whatsapp_calling_configuration?account_id=#{account.id}", params: {
      whatsapp_calling_configuration: { enabled: '1', waba_id: configuration.waba_id,
                                        phone_number_id: configuration.phone_number_id, access_token: '' }
    }

    expect(response).to have_http_status(:found)
    expect(account.reload.feature_enabled?('channel_voice')).to be true
  end

  it 'enables only a compatible whatsapp_cloud inbox through the existing channel method' do
    configuration
    provider_service = instance_double(Whatsapp::Providers::WhatsappCloudService, update_calling_status: true)
    webhook_service = instance_double(Whatsapp::WebhookSetupService, register_callback: true)
    allow(Whatsapp::Providers::WhatsappCloudService).to receive(:new).and_return(provider_service)
    allow(Whatsapp::WebhookSetupService).to receive(:new).and_return(webhook_service)

    post '/super_admin/whatsapp_calling_configuration/enable_inbox_calling',
         params: { account_id: account.id, inbox_id: channel.inbox.id }

    expect(response).to have_http_status(:found)
    expect(channel.reload.provider_config['calling_enabled']).to be true
    expect(provider_service).to have_received(:update_calling_status).with('ENABLED')
  end

  it 'does not enable an inbox with a different Phone Number ID' do
    configuration.update!(phone_number_id: '999999999')
    configuration.update!(configuration_status: 'configured')

    post '/super_admin/whatsapp_calling_configuration/enable_inbox_calling',
         params: { account_id: account.id, inbox_id: channel.inbox.id }

    expect(response).to have_http_status(:found)
    expect(channel.reload.provider_config['calling_enabled']).not_to be true
    expect(flash[:alert]).to include('não corresponde ao Phone Number ID')
  end
end
