require 'rails_helper'

RSpec.describe 'Sales opportunities API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, name: '', identifier: 'instagram_user', email: nil, phone_number: nil, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/sales/opportunities" }

  before { account.enable_features!('sales') }

  it 'creates an opportunity for a contact without phone or email' do
    post base_url,
         params: { opportunity: { contact_id: contact.id, title: 'Instagram sale', temperature: 'hot' } },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig('contact', 'identifier')).to eq('instagram_user')
    expect(account.sales_opportunities.last.owner).to eq(agent)
  end

  it 'rejects the API while the module is disabled' do
    account.disable_features!('sales')

    get base_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it 'does not expose another agents opportunities' do
    pipeline = Sales::DefaultPipelineService.new(account).perform
    other_agent = create(:user, account: account, role: :agent)
    create(:sales_opportunity, account: account, sales_pipeline: pipeline,
                               sales_stage: pipeline.sales_stages.first, contact: contact, owner: other_agent)
    own_opportunity = create(:sales_opportunity, account: account, sales_pipeline: pipeline,
                                                 sales_stage: pipeline.sales_stages.first, contact: contact, owner: agent)

    get base_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['opportunities'].pluck('id')).to eq([own_opportunity.id])

    get "#{base_url}/#{account.sales_opportunities.find_by!(owner: other_agent).id}",
        headers: agent.create_new_auth_token,
        as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'allows an administrator to see every opportunity in the account' do
    admin = create(:user, account: account, role: :administrator)
    pipeline = Sales::DefaultPipelineService.new(account).perform
    create(:sales_opportunity, account: account, sales_pipeline: pipeline,
                               sales_stage: pipeline.sales_stages.first, contact: contact, owner: agent)

    get base_url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['opportunities'].size).to eq(1)
  end

  it 'rejects a contact from another account' do
    foreign_contact = create(:contact)

    post base_url,
         params: { opportunity: { contact_id: foreign_contact.id, title: 'Cross-account sale' } },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'allows multiple legitimate opportunities for the same contact' do
    2.times do |number|
      post base_url,
           params: { opportunity: { contact_id: contact.id, title: "Sale #{number}", idempotency_key: "request-#{number}" } },
           headers: agent.create_new_auth_token,
           as: :json
    end

    expect(account.sales_opportunities.where(contact: contact).count).to eq(2)
  end

  it 'uses the idempotency key to prevent accidental duplicate requests' do
    2.times do
      post base_url,
           params: { opportunity: { contact_id: contact.id, title: 'One sale', idempotency_key: 'same-request' } },
           headers: agent.create_new_auth_token,
           as: :json
    end

    expect(account.sales_opportunities.where(contact: contact).count).to eq(1)
  end
end
