require 'rails_helper'

RSpec.describe 'CRM wallet API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { JrcCrm::DefaultPipelineService.new(account).perform }
  let(:stage) { pipeline.stages.active.order(:position).first }
  let(:base_url) { "/api/v1/accounts/#{account.id}/crm/wallet" }

  before { account.enable_features!('jrc_crm') }

  it 'loads the current user wallet through the singular route' do
    JrcCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, owner: agent,
                         title: 'Carteira ativa', value_cents: 200_000)
    JrcCrm::Lead.create!(account: account, owner: agent, name: 'Lead novo', status: 'new')
    JrcCrm::Activity.create!(account: account, user: agent, deal: account.jrc_crm_deals.first,
                             activity_type: 'follow_up', title: 'Retornar hoje',
                             due_at: Time.zone.now.change(hour: 10))

    get base_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('totals', 'active_deals_count')).to eq(1)
    expect(response.parsed_body.dig('owner', 'name')).to eq(agent.name)
    expect(response.parsed_body.fetch('active_deals').first.dig('stage', 'name')).to eq(stage.name)
  end
end
