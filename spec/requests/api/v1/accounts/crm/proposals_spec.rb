require 'rails_helper'

RSpec.describe 'CRM proposals API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { JrcCrm::DefaultPipelineService.new(account).perform }
  let(:stage) { pipeline.stages.active.order(:position).first }
  let(:deal) do
    JrcCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, owner: agent,
                         title: 'Negócio - Cliente Teste CRM', value_cents: 100_000)
  end
  let(:proposal) do
    JrcCrm::Proposal.create!(account: account, deal: deal, owner: agent,
                             title: 'Proposta - Cliente Teste CRM', status: 'draft')
  end
  let(:base_url) { "/api/v1/accounts/#{account.id}/crm/proposals" }

  before { account.enable_features!('jrc_crm') }

  it 'opens a proposal with its deal title' do
    get "#{base_url}/#{proposal.id}", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('deal', 'title')).to eq(deal.title)
  end

  it 'adds, persists and totals product items in cents' do
    product = JrcCrm::Product.create!(account: account, name: 'Serviço Teste CRM',
                                     sku: 'TESTE-001', category: 'Serviços',
                                     unit_price_cents: 50_000, active: true)

    post "#{base_url}/#{proposal.id}/items",
         params: { item: { product_id: product.id, quantity: 2 } },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['items_count']).to eq(1)
    expect(response.parsed_body['subtotal_cents']).to eq(100_000)
    expect(response.parsed_body['total_cents']).to eq(100_000)

    get "#{base_url}/#{proposal.id}", headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.fetch('items').first['name_snapshot']).to eq('Serviço Teste CRM')
    expect(response.parsed_body['total_cents']).to eq(100_000)
  end
end
