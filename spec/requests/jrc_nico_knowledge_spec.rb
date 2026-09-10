require 'rails_helper'

RSpec.describe 'NICO reviewed knowledge', type: :request do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:path) { "/api/v1/accounts/#{account.id}/jrc_nico/knowledge_documents" }
  let(:headers) { admin.create_new_auth_token }

  it 'requires explicit approval of the exact document and invalidates approval after an edit' do
    post path, params: { title: 'Implantação', body: 'Checklist de demonstração' }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    document = response.parsed_body
    expect(document['approved_at']).to be_nil
    post "#{path}/#{document['id']}/approve", params: { digest: 'outdated' }, headers: headers, as: :json
    expect(response).to have_http_status(:conflict)
    post "#{path}/#{document['id']}/approve", params: { digest: document['digest'] }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['approved_by_id']).to eq(admin.id)
    patch "#{path}/#{document['id']}", params: { body: 'Checklist revisado' }, headers: headers, as: :json
    expect(response.parsed_body['approved_at']).to be_nil
  end

  it 'denies document management to an operator' do
    operator = create(:user, account: account, role: :agent)
    get path, headers: operator.create_new_auth_token
    expect(response).to have_http_status(:forbidden)
  end
end
