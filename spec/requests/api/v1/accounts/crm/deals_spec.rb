require 'rails_helper'

RSpec.describe 'CRM deals API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/crm/deals" }
  let(:pipeline) { JrcCrm::DefaultPipelineService.new(account).perform }
  let(:stage) { pipeline.stages.active.order(:position).first }

  before { account.enable_features!('jrc_crm') }

  it 'rejects the API while the feature is disabled' do
    account.disable_features!('jrc_crm')

    get base_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it 'creates a deal for a contact without phone or email' do
    contact = create(:contact, account: account, name: '', identifier: 'instagram.crm', email: nil, phone_number: nil)

    post base_url,
         params: { deal: { title: 'Instagram', pipeline_id: pipeline.id, stage_id: stage.id,
                           contact_id: contact.id, value_cents: 15_000 } },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig('contact', 'identifier')).to eq('instagram.crm')
  end

  it 'returns stage, owner, contact and next future activity for kanban and details' do
    contact = create(:contact, account: account, name: 'Cliente Teste CRM')
    deal = JrcCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, owner: agent,
                               contact: contact, title: 'Negócio completo', value_cents: 100_000)
    JrcCrm::Activity.create!(account: account, user: agent, deal: deal, activity_type: 'follow_up',
                             title: 'Follow-up', due_at: 1.day.from_now)

    get base_url, headers: agent.create_new_auth_token, as: :json

    serialized_deal = response.parsed_body.find { |item| item['id'] == deal.id }
    expect(serialized_deal.dig('stage', 'name')).to eq(stage.name)
    expect(serialized_deal.dig('owner', 'name')).to eq(agent.name)
    expect(serialized_deal.dig('contact', 'name')).to eq('Cliente Teste CRM')
    expect(serialized_deal.dig('next_activity', 'title')).to eq('Follow-up')

    get "#{base_url}/#{deal.id}", headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body.dig('stage', 'id')).to eq(stage.id)
    expect(response.parsed_body.dig('owner', 'id')).to eq(agent.id)
    expect(response.parsed_body.dig('contact', 'id')).to eq(contact.id)
    expect(response.parsed_body['contact_id']).to eq(contact.id)
  end

  it 'returns the same serialized relationship contract after moving a deal' do
    contact = create(:contact, account: account, name: 'Cliente movido')
    target_stage = pipeline.stages.active.order(:position).second
    deal = JrcCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, owner: agent,
                               contact: contact, title: 'Negócio movido', value_cents: 100_000)

    post "#{base_url}/#{deal.id}/move_stage",
         params: { stage_id: target_stage.id },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('deal', 'stage', 'id')).to eq(target_stage.id)
    expect(response.parsed_body.dig('deal', 'owner', 'id')).to eq(agent.id)
    expect(response.parsed_body.dig('deal', 'contact', 'id')).to eq(contact.id)

    get base_url, headers: agent.create_new_auth_token, as: :json
    serialized_deal = response.parsed_body.find { |item| item['id'] == deal.id }
    expect(serialized_deal.dig('stage', 'id')).to eq(target_stage.id)

    get "#{base_url}/#{deal.id}", headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.dig('stage', 'id')).to eq(target_stage.id)
  end

  it 'limits an agent to owned records and lets an administrator see the account records' do
    other_agent = create(:user, account: account, role: :agent)
    own_deal = JrcCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, owner: agent,
                                   title: 'Próprio', value_cents: 0)
    JrcCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, owner: other_agent,
                        title: 'Outro', value_cents: 0)

    get base_url, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.pluck('id')).to eq([own_deal.id])

    admin = create(:user, account: account, role: :administrator)
    get base_url, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body.size).to eq(2)
  end

  it 'does not expose a deal from another account' do
    foreign_account = create(:account)
    foreign_owner = create(:user, account: foreign_account)
    foreign_pipeline = JrcCrm::DefaultPipelineService.new(foreign_account).perform
    foreign_deal = JrcCrm::Deal.create!(account: foreign_account, pipeline: foreign_pipeline,
                                       stage: foreign_pipeline.stages.first, owner: foreign_owner,
                                       title: 'Externo', value_cents: 0)

    get "#{base_url}/#{foreign_deal.id}", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
