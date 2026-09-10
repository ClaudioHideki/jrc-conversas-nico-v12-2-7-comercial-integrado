require 'rails_helper'

RSpec.describe 'NICO ERP configuration', type: :request do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }
  let(:path) { "/api/v1/accounts/#{account.id}/jrc_nico/erp" }
  let(:headers) { admin.create_new_auth_token }

  it 'denies configuration for an account outside the allowlist' do
    with_modified_env ERP_ALLOWED_ACCOUNTS: '' do
      patch path, params: { conversation_id: conversation.display_id, mode: 'fixture' }, headers: headers, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(JrcNico::ErpSetting.count).to eq(0)
    end
  end

  it 'stores operator and requester separately without binding the contact' do
    with_modified_env ERP_ALLOWED_ACCOUNTS: account.id.to_s do
      patch path, params: { conversation_id: conversation.display_id, mode: 'fixture', operator_company_id: '3', requester_user_id: '4912' }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['settings']).to include('operator_company_id' => '3', 'requester_user_id' => '4912')
      expect(response.parsed_body['binding']).to be_nil
    end
  end

  it 'does not bind another account conversation' do
    other = create(:conversation)
    with_modified_env ERP_ALLOWED_ACCOUNTS: account.id.to_s do
      get path, params: { conversation_id: other.display_id + 1_000_000 }, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
