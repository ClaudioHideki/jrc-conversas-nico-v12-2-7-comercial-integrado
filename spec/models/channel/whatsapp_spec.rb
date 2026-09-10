# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join 'spec/models/concerns/reauthorizable_shared.rb'

RSpec.describe Channel::Whatsapp do
  describe 'concerns' do
    let(:channel) { create(:channel_whatsapp) }

    before do
      stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
      stub_request(:get, 'https://waba.360dialog.io/v1/configs/templates')
    end

    it_behaves_like 'reauthorizable'

    context 'when prompt_reauthorization!' do
      it 'calls channel notifier mail for whatsapp' do
        admin_mailer = double
        mailer_double = double

        expect(AdministratorNotifications::ChannelNotificationsMailer).to receive(:with).and_return(admin_mailer)
        expect(admin_mailer).to receive(:whatsapp_disconnect).with(channel.inbox).and_return(mailer_double)
        expect(mailer_double).to receive(:deliver_later)

        channel.prompt_reauthorization!
      end
    end
  end

  describe 'validate_provider_config' do
    let(:channel) { build(:channel_whatsapp, provider: 'whatsapp_cloud', account: create(:account)) }

    it 'validates false when provider config is wrong' do
      stub_request(:get, 'https://graph.facebook.com/v14.0//message_templates?access_token=test_key').to_return(status: 401)
      expect(channel.save).to be(false)
    end

    it 'validates true when provider config is right' do
      stub_request(:get, 'https://graph.facebook.com/v14.0//message_templates?access_token=test_key')
        .to_return(status: 200,
                   body: { data: [{
                     id: '123456789', name: 'test_template'
                   }] }.to_json)
      stub_request(:get, 'https://graph.facebook.com/v14.0//phone_numbers?fields=id&limit=100&access_token=test_key')
        .to_return(status: 200, body: { data: [{ id: 'random_id' }] }.to_json, headers: { 'Content-Type' => 'application/json' })
      expect(channel.save).to be(true)
    end

    it 'validates false when phone number id is wrong' do
      stub_request(:get, 'https://graph.facebook.com/v14.0//message_templates?access_token=test_key')
        .to_return(status: 200, body: { data: [] }.to_json)
      stub_request(:get, 'https://graph.facebook.com/v14.0//phone_numbers?fields=id&limit=100&access_token=test_key')
        .to_return(status: 200, body: { data: [{ id: 'another_phone_id' }] }.to_json, headers: { 'Content-Type' => 'application/json' })
      expect(channel.save).to be(false)
    end
  end

  describe 'webhook_verify_token' do
    before do
      # Stub webhook setup to prevent HTTP calls during channel creation
      setup_service = instance_double(Whatsapp::WebhookSetupService)
      allow(Whatsapp::WebhookSetupService).to receive(:new).and_return(setup_service)
      allow(setup_service).to receive(:perform)
    end

    it 'generates webhook_verify_token if not present' do
      channel = create(:channel_whatsapp,
                       provider_config: {
                         'webhook_verify_token' => nil,
                         'api_key' => 'test_key',
                         'business_account_id' => '123456789'
                       },
                       provider: 'whatsapp_cloud',
                       account: create(:account),
                       validate_provider_config: false,
                       sync_templates: false)

      expect(channel.provider_config['webhook_verify_token']).not_to be_nil
    end

    it 'does not generate webhook_verify_token if present' do
      channel = create(:channel_whatsapp,
                       provider: 'whatsapp_cloud',
                       provider_config: {
                         'webhook_verify_token' => '123',
                         'api_key' => 'test_key',
                         'business_account_id' => '123456789'
                       },
                       account: create(:account),
                       validate_provider_config: false,
                       sync_templates: false)

      expect(channel.provider_config['webhook_verify_token']).to eq '123'
    end
  end

  describe 'webhook setup after creation' do
    let(:account) { create(:account) }
    let(:webhook_service) { instance_double(Whatsapp::WebhookSetupService) }

    before do
      allow(Whatsapp::WebhookSetupService).to receive(:new).and_return(webhook_service)
      allow(webhook_service).to receive(:perform)
    end

    context 'when channel is created through embedded signup' do
      it 'does not raise error if webhook setup fails' do
        allow(webhook_service).to receive(:perform).and_raise(StandardError, 'Webhook error')

        expect do
          create(:channel_whatsapp,
                 account: account,
                 provider: 'whatsapp_cloud',
                 provider_config: {
                   'source' => 'embedded_signup',
                   'business_account_id' => 'test_waba_id',
                   'api_key' => 'test_access_token'
                 },
                 validate_provider_config: false,
                 sync_templates: false)
        end.not_to raise_error
      end
    end

    context 'when channel is created through manual setup' do
      it 'setups webhooks via after_commit callback' do
        expect(Whatsapp::WebhookSetupService).to receive(:new).and_return(webhook_service)
        expect(webhook_service).to receive(:perform)

        # Explicitly set source to nil to test manual setup behavior (not embedded_signup)
        create(:channel_whatsapp,
               account: account,
               provider: 'whatsapp_cloud',
               provider_config: {
                 'business_account_id' => 'test_waba_id',
                 'api_key' => 'test_access_token',
                 'source' => nil
               },
               validate_provider_config: false,
               sync_templates: false)
      end
    end

    context 'when channel is created with different provider' do
      it 'does not setup webhooks for 360dialog provider' do
        expect(Whatsapp::WebhookSetupService).not_to receive(:new)

        create(:channel_whatsapp,
               account: account,
               provider: 'default',
               provider_config: {
                 'source' => 'embedded_signup',
                 'api_key' => 'test_360dialog_key'
               },
               validate_provider_config: false,
               sync_templates: false)
      end
    end
  end

  describe '#teardown_webhooks' do
    let(:account) { create(:account) }

    context 'when channel is whatsapp_cloud with embedded_signup' do
      it 'calls WebhookTeardownService on destroy' do
        # Mock the setup service to prevent HTTP calls during creation
        setup_service = instance_double(Whatsapp::WebhookSetupService)
        allow(Whatsapp::WebhookSetupService).to receive(:new).and_return(setup_service)
        allow(setup_service).to receive(:perform)

        channel = create(:channel_whatsapp,
                         account: account,
                         provider: 'whatsapp_cloud',
                         provider_config: {
                           'source' => 'embedded_signup',
                           'business_account_id' => 'test_waba_id',
                           'api_key' => 'test_access_token',
                           'phone_number_id' => '123456789'
                         },
                         validate_provider_config: false,
                         sync_templates: false)

        teardown_service = instance_double(Whatsapp::WebhookTeardownService)
        allow(Whatsapp::WebhookTeardownService).to receive(:new).with(channel).and_return(teardown_service)
        allow(teardown_service).to receive(:perform)

        channel.destroy

        expect(Whatsapp::WebhookTeardownService).to have_received(:new).with(channel)
        expect(teardown_service).to have_received(:perform)
      end
    end

    context 'when channel is not embedded_signup' do
      it 'calls WebhookTeardownService on destroy' do
        # Mock the setup service to prevent HTTP calls during creation
        setup_service = instance_double(Whatsapp::WebhookSetupService)
        allow(Whatsapp::WebhookSetupService).to receive(:new).and_return(setup_service)
        allow(setup_service).to receive(:perform)

        channel = create(:channel_whatsapp,
                         account: account,
                         provider: 'whatsapp_cloud',
                         provider_config: {
                           'business_account_id' => 'test_waba_id',
                           'api_key' => 'test_access_token'
                         },
                         validate_provider_config: false,
                         sync_templates: false)

        teardown_service = instance_double(Whatsapp::WebhookTeardownService)
        allow(Whatsapp::WebhookTeardownService).to receive(:new).with(channel).and_return(teardown_service)
        allow(teardown_service).to receive(:perform)

        channel.destroy

        expect(teardown_service).to have_received(:perform)
      end
    end
  end

  describe '#voice_enabled?' do
    let(:account) { create(:account) }

    before do
      account.enable_features!('channel_voice')
      configuration = WhatsappCallingConfiguration.create!(
        account: account, enabled: true, waba_id: '123456789', phone_number_id: '123456789', access_token: 'protected-token'
      )
      configuration.update!(configuration_status: 'configured')
    end

    it 'returns true for embedded-signup whatsapp_cloud channels with calling_enabled' do
      channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                                          validate_provider_config: false, sync_templates: false)
      channel.update!(provider_config: channel.provider_config.merge('source' => 'embedded_signup', 'calling_enabled' => true))

      expect(channel.voice_enabled?).to be true
    end

    it 'returns true for manual whatsapp_cloud channels with calling_enabled' do
      channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                                          validate_provider_config: false, sync_templates: false)
      channel.update!(provider_config: channel.provider_config.merge('source' => 'manual', 'calling_enabled' => true))

      expect(channel.voice_enabled?).to be true
    end

    it 'returns false for default-provider channels (360dialog) even with calling_enabled' do
      channel = create(:channel_whatsapp, account: account, provider: 'default',
                                          validate_provider_config: false, sync_templates: false)
      channel.update!(provider_config: channel.provider_config.merge('source' => 'embedded_signup', 'calling_enabled' => true))

      expect(channel.voice_enabled?).to be false
    end

    it 'returns false when the channel_voice feature is disabled on the account' do
      account.disable_features!('channel_voice')
      channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                                          validate_provider_config: false, sync_templates: false)
      channel.update!(provider_config: channel.provider_config.merge('source' => 'embedded_signup', 'calling_enabled' => true))

      expect(channel.voice_enabled?).to be false
    end
  end

  describe 'WhatsApp Calling activation' do
    let(:account) { create(:account) }
    let(:channel) do
      create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                                validate_provider_config: false, sync_templates: false)
    end
    let(:provider_service) { instance_double(Whatsapp::Providers::WhatsappCloudService) }
    let(:webhook_service) { instance_double(Whatsapp::WebhookSetupService, register_callback: true) }

    before do
      account.enable_features!('channel_voice')
      configuration = WhatsappCallingConfiguration.create!(
        account: account, enabled: true, waba_id: '123456789',
        phone_number_id: channel.provider_config['phone_number_id'], access_token: 'protected-token'
      )
      configuration.update!(configuration_status: 'configured')
      allow(channel).to receive(:provider_service).and_return(provider_service)
      allow(channel).to receive(:webhook_setup_service).and_return(webhook_service)
    end

    it 'persists calling_enabled only after Meta succeeds' do
      allow(provider_service).to receive(:update_calling_status).with('ENABLED').and_return(true)

      channel.enable_voice_calling!

      expect(channel.reload.provider_config['calling_enabled']).to be true
    end

    it 'does not persist calling_enabled when Meta rejects activation' do
      allow(provider_service).to receive(:update_calling_status).and_raise('Meta rejected activation')

      expect { channel.enable_voice_calling! }.to raise_error('Meta rejected activation')
      expect(channel.reload.provider_config['calling_enabled']).not_to be true
    end

    it 'disables calling without removing the inbox or configuration' do
      channel.update!(provider_config: channel.provider_config.merge('calling_enabled' => true))

      channel.disable_voice_calling!

      expect(channel.reload.provider_config['calling_enabled']).to be false
      expect(account.reload.whatsapp_calling_configuration).to be_present
    end
  end

  describe '#inbound_calls_enabled?' do
    let(:account) { create(:account) }

    it 'returns true by default when nothing has been toggled' do
      channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                                          validate_provider_config: false, sync_templates: false)
      expect(channel.inbound_calls_enabled?).to be true
    end

    it 'returns false only when explicitly disabled in provider_config' do
      channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                                          validate_provider_config: false, sync_templates: false)
      channel.update!(provider_config: channel.provider_config.merge('inbound_calls_enabled' => false))

      expect(channel.inbound_calls_enabled?).to be false
    end
  end
end
