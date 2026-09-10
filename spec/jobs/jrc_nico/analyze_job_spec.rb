require 'rails_helper'

RSpec.describe JrcNico::AnalyzeJob do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }
  let!(:run) { JrcNico::Run.create!(account: account, user: user, conversation: conversation, request_id: SecureRandom.uuid, message: 'Resumo') }
  let(:result) { { 'summary' => 'Simulação', 'suggested_reply' => '', 'evidence' => [], 'warnings' => [], 'usage' => nil, 'model' => 'fixture-local', 'mode' => 'fixture' } }

  it 'executes an accepted request once even if the queue delivers twice' do
    client = instance_double(JrcNico::RuntimeClient)
    allow(JrcNico::RuntimeClient).to receive(:new).and_return(client)
    expect(client).to receive(:analyze).once.and_return(result)
    described_class.perform_now(run.id)
    described_class.perform_now(run.id)
    expect(run.reload.status).to eq('completed')
    expect(run.result).to eq(result)
  end

  it 'fails after membership is revoked without calling the runtime' do
    account.account_users.find_by!(user_id: user.id).destroy!
    expect(JrcNico::RuntimeClient).not_to receive(:new)
    described_class.perform_now(run.id)
    expect(run.reload.status).to eq('failed')
  end

  it 'does not restore a result cancelled while analysis was running' do
    client = instance_double(JrcNico::RuntimeClient)
    allow(JrcNico::RuntimeClient).to receive(:new).and_return(client)
    allow(client).to receive(:analyze) do
      run.update!(status: 'cancelled', finished_at: Time.current)
      result
    end
    described_class.perform_now(run.id)
    expect(run.reload.status).to eq('cancelled')
    expect(run.result).to eq({})
  end

  it 'records failure without fabricating success or sending a message' do
    allow(JrcNico::RuntimeClient).to receive(:new).and_raise(JrcNico::RuntimeClient::Error, 'Unavailable')
    expect { described_class.perform_now(run.id) }.not_to change(Message, :count)
    expect(run.reload.status).to eq('failed')
    expect(run.error_code).to eq('analysis_unavailable')
  end
end
