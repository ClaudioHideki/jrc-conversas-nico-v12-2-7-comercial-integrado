require 'rails_helper'

RSpec.describe 'JRC Broker native contract', type: :request do
  self.use_transactional_tests = false

  it 'keeps reconnect authority separate from the generic inbox policy' do
    expect(InboxPolicy.instance_methods(false)).to include(:create?, :update?)
    expect(JrcBrokerPolicy.instance_methods(false)).to include(:pair?, :disconnect?)
  end

  context 'with the isolated TLS Broker and Rails processes', if: ENV['CONTRACT_TEST_ONLY'] == 'true' do
    let(:rails_fixture) { JSON.parse(File.read('/contract/rails-fixture.json')) }
    let(:broker_fixture) { JSON.parse(File.read('/contract/broker-fixture.json')) }
    let(:account) { Account.find(rails_fixture.fetch('accountId')) }
    let(:prefix) { "/api/v1/accounts/#{account.id}/jrc_broker" }
    let(:headers) { { 'api_access_token' => rails_fixture.fetch('chatwootToken'), 'Idempotency-Key' => SecureRandom.uuid } }
    let(:setup) do
      { origin: 'https://broker.example.test', organizationId: broker_fixture.fetch('organizationId'),
        controlKey: broker_fixture.fetch('credential').fetch('secret') }
    end

    around do |example|
      raise 'ISOLATED_DATABASE_REQUIRED' unless ActiveRecord::Base.connection_db_config.database == 'jrc_broker_native_test'

      WebMock.disable_net_connect!(allow: ['broker.example.test'])
      with_modified_env(JRC_BROKER_ENABLED: 'true', JRC_BROKER_ALLOWED_ORIGINS: 'https://broker.example.test',
                        JRC_BROKER_CREDENTIAL_KEY: Base64.strict_encode64('k' * 32), FRONTEND_URL: 'https://chatwoot.example.test') { example.run }
    ensure
      WebMock.disable_net_connect!(allow_localhost: true)
    end

    # Keep the sequential HTTP assertions visible in this shared contract protocol.
    def perform_onboarding # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      expect(JrcBroker::Configuration.enabled?).to be(true)
      expect(account.feature_enabled?('jrc_broker')).to be(true)
      patch prefix, headers: headers, params: setup, as: :json
      expect(response).to have_http_status(:ok), response.parsed_body.slice('error', 'code').inspect
      expect(response.body).not_to include(setup[:controlKey])
      body = { name: "Synthetic #{SecureRandom.hex(4)}", source: { kind: 'NEW', instanceName: "Contract #{SecureRandom.hex(4)}",
                                                                   providerAccountId: broker_fixture.fetch('providerId') },
               agentIds: [rails_fixture.fetch('adminId'), rails_fixture.fetch('agentId')], replaceExistingWebhook: false }
      2.times do
        post "#{prefix}/onboarding", headers: headers, params: body, as: :json
        expect(response).to have_http_status(:accepted)
      end
      id = response.parsed_body.fetch('operationId')
      deadline = 40.seconds.from_now
      loop do
        get "#{prefix}/onboarding/#{id}", headers: headers
        expect(response).to have_http_status(:ok)
        break if response.parsed_body['state'] == 'SUCCEEDED' || Time.current >= deadline
        if response.parsed_body['state'] == 'FAILED' || response.parsed_body['state'] == 'UNKNOWN'
          raise "ONBOARDING_FAILED: #{response.parsed_body.slice('state', 'stage', 'lastError')}"
        end

        sleep 0.3
      end
      expect(response.parsed_body['state']).to eq('SUCCEEDED')
      response.parsed_body
    end

    # Keep the same persisted inbox across binding, pairing, isolation and rollback checks.
    it 'creates one real API inbox, binds it, pairs through authenticated BFF and rejects a different account key' do # rubocop:disable RSpec/MultipleExpectations
      result = perform_onboarding
      inbox = account.inboxes.find(result.fetch('inboxId'))
      expect(inbox.channel_type).to eq('Channel::Api')
      expect(account.inboxes.where(name: inbox.name).count).to eq(1)
      expect(JrcBrokerInboxBinding.find_by!(inbox: inbox).integration_id).to eq(result.fetch('integrationId'))
      post "#{prefix}/inboxes/#{inbox.id}/pair", headers: headers, params: {}, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch('action')).to include('type' => 'PAIRING_CODE', 'code' => 'TESTONLY')
      expect(response.headers['Cache-Control']).to eq('no-store')
      patch "/api/v1/accounts/#{rails_fixture.fetch('otherAccountId')}/jrc_broker", headers: headers, params: setup, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JrcBrokerIntegration.exists?(account_id: rails_fixture.fetch('otherAccountId'))).to be(false)
      evidence = JSON.parse(Net::HTTP.get(URI('https://broker.example.test/__contract/evidence')))
      expect(evidence.fetch('inboxPosts')).to be_positive
      expect(evidence.fetch('maxIdleTransactions')).to eq(0)
      with_modified_env(JRC_BROKER_ENABLED: 'false') do
        get "#{prefix}/inboxes/#{inbox.id}/status", headers: headers
        expect(response).to have_http_status(:not_found)
        expect(inbox.channel.reload.webhook_url).to be_present
      end
    end

    it 'recovers a real pre-ACK failure and persists one signed outgoing event in the Broker' do
      inbox = account.inboxes.find(perform_onboarding.fetch('inboxId'))
      contact = create(:contact, account: account, email: "#{SecureRandom.uuid}@example.test")
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
      message = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                                 sender: User.find(rails_fixture.fetch('adminId')), content: 'Synthetic pre-ACK contract')
      payload = message.webhook_data.merge(event: 'message_created')
      clear_enqueued_jobs
      delivery_id = SecureRandom.uuid
      # Gateway is armed by the local harness to reject the first callback before forwarding.
      perform_enqueued_jobs(only: WebhookJob) do
        WebhookJob.perform_later(inbox.channel.webhook_url, payload, :api_inbox_webhook, secret: inbox.channel.secret, delivery_id: delivery_id)
      end
      expect(message.reload.status).to eq('sent')
      db = PG.connect(host: 'broker-postgres', user: 'postgres', dbname: 'jrc_contract_20260916')
      jobs = db.exec_params("SELECT count(*) FROM integration_jobs WHERE organization_id=$1 AND kind='CHATWOOT_REPLY' AND dedupe_key=$2",
                            [broker_fixture.fetch('organizationId'), "reply:#{message.id}"])
      expect(jobs[0]['count']).to eq('1')
      evidence = JSON.parse(Net::HTTP.get(URI('https://broker.example.test/__contract/evidence')))
      expect(evidence.fetch('rejectedBeforeAck')).to eq(1)
      expect(evidence.fetch('callbacks')).to be >= 2
      WebhookJob.perform_now(inbox.channel.webhook_url, payload, :api_inbox_webhook, secret: inbox.channel.secret, delivery_id: delivery_id)
      jobs = db.exec_params("SELECT count(*) FROM integration_jobs WHERE organization_id=$1 AND kind='CHATWOOT_REPLY' AND dedupe_key=$2",
                            [broker_fixture.fetch('organizationId'), "reply:#{message.id}"])
      expect(jobs[0]['count']).to eq('1')
      # The real Broker must reject a forged signature without persisting a second event.
      uri = URI(inbox.channel.webhook_url)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['X-Chatwoot-Delivery'] = SecureRandom.uuid
      request['X-Chatwoot-Timestamp'] = Time.now.to_i.to_s
      request['X-Chatwoot-Signature'] = "sha256=#{'0' * 64}"
      request.body = payload.merge(id: message.id + 1_000_000).to_json
      result = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      expect(result.code).to eq('401')
    ensure
      db&.close
      clear_enqueued_jobs
    end
  end
end
