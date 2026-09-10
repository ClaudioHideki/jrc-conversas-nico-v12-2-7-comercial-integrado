require 'rails_helper'

RSpec.describe 'NICO assisted runs', type: :request do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }
  let(:path) { "/api/v1/accounts/#{account.id}/jrc_nico/runs" }
  let(:headers) { admin.create_new_auth_token }
  let(:input) { { conversation_id: conversation.display_id, message: 'Resuma a conversa', request_id: SecureRandom.uuid } }

  it 'creates a queued, account-scoped run without sending a public message' do
    expect { post path, params: input, headers: headers, as: :json }.not_to change(Message, :count)
    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to include('status' => 'queued', 'conversation_id' => conversation.display_id)
  end

  it 'persists the specialist and rejects changing it under the same request id' do
    request = input.merge(agent_key: 'comercial')
    post path, params: request, headers: headers, as: :json
    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body['agent_key']).to eq('comercial')
    post path, params: request.merge(agent_key: 'cx'), headers: headers, as: :json
    expect(response).to have_http_status(:conflict)
  end

  it 'denies unknown or account-disabled specialists before enqueueing' do
    post path, params: input.merge(agent_key: 'root'), headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    account.update!(custom_attributes: { 'nico_enabled' => true, 'nico_agent_keys' => ['nico'] })
    post path, params: input.merge(agent_key: 'comercial'), headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'reuses an identical request instead of creating duplicate work' do
    request = input
    post path, params: request, headers: headers, as: :json
    expect(response).to have_http_status(:accepted)
    first_id = response.parsed_body.fetch('id')
    post path, params: request, headers: headers, as: :json
    expect(response.parsed_body.fetch('id')).to eq(first_id)
  end

  it 'rejects reusing a request id with changed content' do
    request = input
    post path, params: request, headers: headers, as: :json
    post path, params: request.merge(message: 'Outro pedido'), headers: headers, as: :json
    expect(response).to have_http_status(:conflict)
  end

  it 'denies an operator without visibility of the inbox or team' do
    operator = create(:user, account: account, role: :agent)
    post path, params: input, headers: operator.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'denies membership in a different account' do
    outsider = create(:user, account: create(:account), role: :administrator)
    post path, params: input, headers: outsider.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not accept an account from the request body as authority' do
    other = create(:account)
    post path, params: input.merge(account_id: other.id), headers: headers, as: :json
    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body.fetch('account_id')).to eq(account.id)
  end

  it 'denies creation when the account feature is disabled' do
    account.update!(custom_attributes: {})
    post path, params: input, headers: headers, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'rejects oversized messages' do
    post path, params: input.merge(message: 'a' * 4001), headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'enforces a monthly request limit before enqueueing work' do
    account.update!(custom_attributes: { 'nico_enabled' => true, 'nico_monthly_run_limit' => 0 })
    post path, params: input, headers: headers, as: :json
    expect(response).to have_http_status(:too_many_requests)
  end

  it 'reserves token capacity before a real provider request' do
    account.update!(custom_attributes: { 'nico_enabled' => true, 'nico_monthly_token_limit' => 0 })
    with_modified_env NICO_MODE: 'provider' do
      post path, params: input, headers: headers, as: :json
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  it 'allows the owner to cancel a queued task and prevents viewing it from another account' do
    post path, params: input, headers: headers, as: :json
    expect(response).to have_http_status(:accepted)
    id = response.parsed_body.fetch('id')
    post "#{path}/#{id}/cancel", headers: headers, as: :json
    expect(response.parsed_body.fetch('status')).to eq('cancelled')
    other = create(:account, custom_attributes: { 'nico_enabled' => true })
    other_admin = create(:user, account: other, role: :administrator)
    get "/api/v1/accounts/#{other.id}/jrc_nico/runs/#{id}", headers: other_admin.create_new_auth_token
    expect(response).to have_http_status(:not_found)
  end
end
