require 'rails_helper'

RSpec.describe WebhookJob do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:channel) { create(:channel_api, account: account, webhook_url: 'https://broker.example.test/callback/synthetic-secret') }
  let(:inbox) { channel.inbox }
  let(:message) { create(:message, account: account, inbox: inbox, message_type: :outgoing, content: 'synthetic delivery') }
  let(:payload) { message.webhook_data.merge(event: 'message_created') }
  let(:delivery_id) { SecureRandom.uuid }

  before do
    allow(Resolv).to receive(:getaddresses).and_call_original
    allow(Resolv).to receive(:getaddresses).with('broker.example.test').and_return(['93.184.216.34'])
    store = JrcBroker::CredentialStore.new(key: 'k' * 32)
    JrcBrokerIntegration.create!(account: account, broker_origin: 'https://broker.example.test', organization_id: SecureRandom.uuid,
                                 destination_revision: 1, encrypted_control_key: store.encrypt(account_id: account.id, token: 'synthetic-control'))
    JrcBrokerInboxBinding.create!(account: account, inbox: inbox, integration_id: SecureRandom.uuid, instance_id: SecureRandom.uuid)
    message
    clear_enqueued_jobs
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'recovers a transient failure using the same signed delivery and body even when the UI flag is off' do
    requests = []
    stub_request(:post, channel.webhook_url).to_return do |request|
      requests << request
      { status: requests.length == 1 ? 503 : 204 }
    end
    with_modified_env(JRC_BROKER_ENABLED: 'false') do
      perform_enqueued_jobs(only: described_class) do
        described_class.perform_later(channel.webhook_url, payload, :api_inbox_webhook, secret: channel.secret, delivery_id: delivery_id)
      end
    end
    expect(requests.length).to eq(2)
    expect(requests.map(&:body).uniq).to eq([payload.to_json])
    requests.each do |request|
      expect(request.headers['X-Chatwoot-Delivery']).to eq(delivery_id)
      expected = OpenSSL::HMAC.hexdigest('SHA256', channel.secret, "#{request.headers['X-Chatwoot-Timestamp']}.#{request.body}")
      expect(request.headers['X-Chatwoot-Signature']).to eq("sha256=#{expected}")
    end
    expect(message.reload.status).to eq('sent')
  end

  it 'bounds retries and records only a neutral failure code after exhaustion' do
    request = stub_request(:post, channel.webhook_url).to_timeout
    perform_enqueued_jobs(only: described_class) do
      described_class.perform_later(channel.webhook_url, payload, :api_inbox_webhook, secret: channel.secret, delivery_id: delivery_id)
    end
    expect(request).to have_been_requested.times(8)
    expect(message.reload.status).to eq('failed')
    expect(message.external_error).to eq('JRC_BROKER_DELIVERY_UNAVAILABLE')
    expect(described_class.log_arguments).to be(false)
  end

  it 'rejects an obsolete callback or secret before sending and never logs the URL' do
    payload
    original_url = channel.webhook_url
    channel.update!(webhook_url: 'https://broker.example.test/callback/replaced-secret')
    request = stub_request(:post, original_url).to_return(status: 204)
    expect(Rails.logger).not_to receive(:warn).with(include('synthetic-secret'))
    described_class.perform_now(original_url, payload, :api_inbox_webhook, secret: channel.secret, delivery_id: delivery_id)
    expect(request).not_to have_been_requested
    expect(message.reload.status).to eq('failed')
    expect(message.external_error).to eq('JRC_BROKER_DELIVERY_CONTEXT_CHANGED')
  end

  it 'does not retry permanent rejection, private notes, incoming messages, or unbound inboxes' do
    request = stub_request(:post, channel.webhook_url).to_return(status: 403)
    perform_enqueued_jobs(only: described_class) do
      described_class.perform_later(channel.webhook_url, payload, :api_inbox_webhook, secret: channel.secret, delivery_id: delivery_id)
    end
    expect(request).to have_been_requested.once
    expect(message.reload.external_error).to eq('JRC_BROKER_DELIVERY_REJECTED')
    WebMock.reset!

    [message.tap { |value| value.update!(private: true) }, create(:message, account: account, inbox: inbox)].each do |value|
      stub = stub_request(:post, channel.webhook_url).to_return(status: 503)
      perform_enqueued_jobs(only: described_class) do
        described_class.perform_later(channel.webhook_url, value.webhook_data.merge(event: 'message_created'), :api_inbox_webhook,
                                      secret: channel.secret, delivery_id: SecureRandom.uuid)
      end
      expect(stub).to have_been_requested.once
      WebMock.reset!
    end
    JrcBrokerInboxBinding.find_by!(inbox: inbox).destroy!
    message.update!(private: false)
    request = stub_request(:post, channel.webhook_url).to_return(status: 503)
    perform_enqueued_jobs(only: described_class) do
      described_class.perform_later(channel.webhook_url, payload, :api_inbox_webhook, secret: channel.secret, delivery_id: delivery_id)
    end
    expect(request).to have_been_requested.once
  end
end
