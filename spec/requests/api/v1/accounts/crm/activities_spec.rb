require 'rails_helper'

RSpec.describe 'CRM activities API', type: :request do
  let(:account) { create(:account, reporting_timezone: 'America/Sao_Paulo') }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { JrcCrm::DefaultPipelineService.new(account).perform }
  let(:stage) { pipeline.stages.active.order(:position).first }
  let(:deal) do
    JrcCrm::Deal.create!(account: account, pipeline: pipeline, stage: stage, owner: agent,
                         title: 'Negócio - Cliente Teste CRM', value_cents: 100_000)
  end
  let(:base_url) { "/api/v1/accounts/#{account.id}/crm/activities" }

  before { account.enable_features!('jrc_crm') }
  around { |example| travel_to(Time.utc(2026, 8, 28, 12)) { example.run } }

  it 'stores datetime-local values in account timezone and returns a friendly related label' do
    post base_url,
         params: {
           activity: {
             deal_id: deal.id,
             activity_type: 'follow_up',
             title: 'Retornar contato com cliente',
             due_at: '2026-08-29T10:00'
           }
         },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['due_at_display']).to eq('29/08/2026 10:00')
    expect(response.parsed_body['related_label']).to eq('Negócio - Cliente Teste CRM')
    expect(response.parsed_body['related_type']).to eq('deal')
    expect(response.parsed_body['related_id']).to eq(deal.id)
    expect(response.parsed_body.dig('deal', 'id')).to eq(deal.id)
    expect(JrcCrm::Activity.last.deal_id).to eq(deal.id)

    get base_url, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.first['due_at_display']).to eq('29/08/2026 10:00')
    expect(response.parsed_body.first.dig('deal', 'title')).to eq('Negócio - Cliente Teste CRM')

    get "/api/v1/accounts/#{account.id}/crm/deals", headers: agent.create_new_auth_token, as: :json
    serialized_deal = response.parsed_body.find { |item| item['id'] == deal.id }
    expect(serialized_deal.dig('next_activity', 'title')).to eq('Retornar contato com cliente')
    expect(serialized_deal.dig('next_activity', 'due_at_display')).to eq('29/08/2026 10:00')
  end

  it 'rejects a deal from another account instead of persisting a detached relationship' do
    foreign_account = create(:account)
    foreign_owner = create(:user, account: foreign_account)
    foreign_pipeline = JrcCrm::DefaultPipelineService.new(foreign_account).perform
    foreign_deal = JrcCrm::Deal.create!(account: foreign_account, pipeline: foreign_pipeline,
                                       stage: foreign_pipeline.stages.first, owner: foreign_owner,
                                       title: 'Negócio externo', value_cents: 0)

    post base_url,
         params: { activity: { deal_id: foreign_deal.id, activity_type: 'follow_up',
                               title: 'Não deve vincular', due_at: 1.day.from_now } },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:not_found)
    expect(JrcCrm::Activity.where(account: account, title: 'Não deve vincular')).not_to exist
  end
end
