require 'rails_helper'

RSpec.describe JrcNico::RuntimeClient do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }
  let(:run) { JrcNico::Run.create!(account: account, user: user, conversation: conversation, request_id: SecureRandom.uuid, message: 'Resumo') }
  let(:context) { { conversation: [{ source: 'conversation', reference: 'message:1', text: 'Olá' }], crm: [], knowledge: [] } }
  let(:body) do
    { request_id: run.request_id, account_id: account.id, summary: 'Resumo', suggested_reply: 'Olá',
      evidence: [{ source: 'conversation', reference: 'message:1' }], warnings: [], usage: nil, model: 'fixture-local', mode: 'fixture' }
  end

  it 'sends service credentials and rejects invented citations' do
    with_modified_env NICO_RUNTIME_URL: 'http://runtime:3108', NICO_SERVICE_TOKEN: 'local-test-token-only-not-for-production' do
      stub_request(:post, 'http://runtime:3108/v1/analyze').with(headers: { 'Authorization' => 'Bearer local-test-token-only-not-for-production' })
                                                          .to_return(status: 200, body: body.merge(evidence: [{ source: 'crm', reference: 'deal:999' }]).to_json)
      expect { described_class.new.analyze(run, context) }.to raise_error { |error| expect(error.class.name).to eq('JrcNico::RuntimeClient::Error') }
    end
  end

  it 'rejects a valid-looking response from another account' do
    with_modified_env NICO_RUNTIME_URL: 'http://runtime:3108', NICO_SERVICE_TOKEN: 'local-test-token-only-not-for-production' do
      stub_request(:post, 'http://runtime:3108/v1/analyze').to_return(status: 200, body: body.merge(account_id: account.id + 1).to_json)
      expect { described_class.new.analyze(run, context) }.to raise_error { |error| expect(error.class.name).to eq('JrcNico::RuntimeClient::Error') }
    end
  end

  it 'preserves explicit simulation status and absent real token usage' do
    with_modified_env NICO_RUNTIME_URL: 'http://runtime:3108', NICO_SERVICE_TOKEN: 'local-test-token-only-not-for-production' do
      stub_request(:post, 'http://runtime:3108/v1/analyze').to_return(status: 200, body: body.to_json)
      expect(described_class.new.analyze(run, context)).to include('mode' => 'fixture', 'usage' => nil)
    end
  end
end
