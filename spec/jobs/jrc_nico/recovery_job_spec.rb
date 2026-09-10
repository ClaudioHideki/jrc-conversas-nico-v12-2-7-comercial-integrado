require 'rails_helper'

RSpec.describe 'NICO queue recovery' do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }

  it 'recovers a committed run whose enqueue was lost' do
    run = JrcNico::Run.create!(account: account, user: user, conversation: conversation, request_id: SecureRandom.uuid, message: 'Resumo', created_at: 3.minutes.ago)
    expect { JrcNico::RecoveryJob.perform_now }.to have_enqueued_job(JrcNico::AnalyzeJob).with(run.id)
  end

  it 'marks an abandoned in-flight inference as failed without automatically repeating it' do
    run = JrcNico::Run.create!(account: account, user: user, conversation: conversation, request_id: SecureRandom.uuid, message: 'Resumo', status: 'running', started_at: 5.minutes.ago)
    expect { JrcNico::RecoveryJob.perform_now }.not_to have_enqueued_job(JrcNico::AnalyzeJob)
    expect(run.reload.status).to eq('failed')
  end
end
