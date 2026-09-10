require 'rails_helper'

RSpec.describe 'NICO approved CRM action', type: :request do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }
  let(:lead) { create(:jrc_crm_lead, account: account, owner: admin, contact: conversation.contact) }
  let(:run) do
    JrcNico::Run.create!(account: account, user: admin, conversation: conversation, request_id: SecureRandom.uuid, message: 'Próxima ação',
                        status: 'completed', finished_at: Time.current, source_manifest: [{ source: 'crm', reference: "lead:#{lead.id}" }],
                        result: { evidence: [{ source: 'crm', reference: "lead:#{lead.id}" }] })
  end
  let(:path) { "/api/v1/accounts/#{account.id}/jrc_nico/proposals" }
  let(:headers) { admin.create_new_auth_token }
  let(:input) { { run_id: run.id, lead_id: lead.id, title: 'Retornar ao cliente', due_at: 1.day.from_now.iso8601, request_id: SecureRandom.uuid } }
  before { account.enable_features!('jrc_crm') }

  it 'previews an action without a write and executes the reviewed digest only once' do
    expect { post path, params: input, headers: headers, as: :json }.not_to change(JrcCrm::Activity, :count)
    expect(response).to have_http_status(:created)
    proposal = response.parsed_body
    post "#{path}/#{proposal['id']}/approve", params: { digest: 'stale' }, headers: headers, as: :json
    expect(response).to have_http_status(:conflict)
    expect do
      2.times { post "#{path}/#{proposal['id']}/approve", params: { digest: proposal['digest'] }, headers: headers, as: :json }
    end.to change(JrcCrm::Activity, :count).by(1)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['status']).to eq('executed')
  end

  it 'does not let a client choose a lead outside the analyzed evidence' do
    other = create(:jrc_crm_lead, account: account, owner: admin)
    post path, params: input.merge(lead_id: other.id), headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rechecks CRM permission when approving' do
    post path, params: input, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    proposal = response.parsed_body
    account.disable_features!('jrc_crm')
    expect do
      post "#{path}/#{proposal['id']}/approve", params: { digest: proposal['digest'] }, headers: headers, as: :json
    end.not_to change(JrcCrm::Activity, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it 'creates a commercial opportunity only once after approval' do
    run.update!(agent_key: 'comercial', source_manifest: [{ source: 'crm', reference: "lead:#{lead.id}" }])
    JrcCrm::DefaultPipelineService.new(account).perform
    expect { post path, params: input.merge(action_kind: 'create_deal'), headers: headers, as: :json }.not_to change(JrcCrm::Deal, :count)
    expect(response).to have_http_status(:created)
    proposal = response.parsed_body
    expect do
      2.times { post "#{path}/#{proposal['id']}/approve", params: { digest: proposal['digest'] }, headers: headers, as: :json }
    end.to change(JrcCrm::Deal, :count).by(1)
    expect(response).to have_http_status(:ok)
    expect(JrcCrm::Deal.last.lead_id).to eq(lead.id)
  end

  it 'rejects a tool not granted to the specialist' do
    post path, params: input.merge(action_kind: 'create_deal'), headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'creates an internal support task, not an external ticket' do
    run.update!(agent_key: 'suporte_n1', source_manifest: [{ source: 'crm', reference: "lead:#{lead.id}" }])
    post path, params: input.merge(action_kind: 'task'), headers: headers, as: :json
    expect(response).to have_http_status(:created)
    proposal = response.parsed_body
    post "#{path}/#{proposal['id']}/approve", params: { digest: proposal['digest'] }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(JrcCrm::Activity.last.activity_type).to eq('task')
  end

  it 'blocks approval when an analyzed source is no longer readable' do
    post path, params: input, headers: headers, as: :json
    proposal = response.parsed_body
    run.update!(source_manifest: [{ source: 'knowledge', reference: 'document:999999:revoked' }])
    expect do
      post "#{path}/#{proposal['id']}/approve", params: { digest: proposal['digest'] }, headers: headers, as: :json
    end.not_to change(JrcCrm::Activity, :count)
    expect(response).to have_http_status(:forbidden)
  end
end

