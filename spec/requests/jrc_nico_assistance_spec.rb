require 'rails_helper'

RSpec.describe 'NICO recommendation authorization', type: :request do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:conversation) do
    create(:conversation, account: account, custom_attributes: {
             'nico_assistance' => { 'status' => 'pending', 'agent_key' => 'comercial', 'intent' => 'comercial' }
           })
  end
  let(:path) { "/api/v1/accounts/#{account.id}/jrc_nico/assistance/authorize" }
  let(:headers) { admin.create_new_auth_token }
  let(:input) { { conversation_id: conversation.display_id, create_lead: true } }

  before { account.enable_features!('jrc_crm') }

  it 'authorizes one run and a new lead without sending a message, and refuses a repeated authorization' do
    expect { post path, params: input, headers: headers, as: :json }.not_to change(Message, :count)
    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body.dig('lead', 'status')).to eq('new')
    expect(conversation.reload.custom_attributes.dig('nico_assistance', 'status')).to eq('authorized')
    expect { post path, params: input, headers: headers, as: :json }.not_to change(JrcNico::Run, :count)
    expect(response).to have_http_status(:not_found)
  end

  it 'applies the monthly run limit before creating a lead or authorizing the recommendation' do
    account.update!(custom_attributes: account.custom_attributes.merge('nico_monthly_run_limit' => 0))
    expect { post path, params: input, headers: headers, as: :json }.not_to change(JrcCrm::Lead, :count)
    expect(response).to have_http_status(:too_many_requests)
    expect(JrcNico::Run.where(account: account)).to be_empty
    expect(conversation.reload.custom_attributes.dig('nico_assistance', 'status')).to eq('pending')
  end

  it 'checks provider token capacity before authorization' do
    account.update!(custom_attributes: account.custom_attributes.merge('nico_monthly_token_limit' => 0))
    with_modified_env NICO_MODE: 'provider' do
      expect { post path, params: input, headers: headers, as: :json }.not_to change(JrcNico::Run, :count)
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  it 'does not start a second analysis while the account has active work' do
    JrcNico::Run.create!(account: account, user: admin, conversation: conversation,
                         message: 'Análise em andamento', request_id: SecureRandom.uuid)
    expect { post path, params: input, headers: headers, as: :json }.not_to change(JrcNico::Run, :count)
    expect(response).to have_http_status(:too_many_requests)
  end

  it 'denies CRM creation to an operator who can read the conversation but lacks CRM access' do
    operator = create(:user, account: account, role: :agent)
    create(:inbox_member, inbox: conversation.inbox, user: operator)
    account.disable_features!('jrc_crm')
    expect do
      post path, params: input, headers: operator.create_new_auth_token, as: :json
    end.not_to change(JrcCrm::Lead, :count)
    expect(response).to have_http_status(:forbidden)
    expect(JrcNico::Run.where(account: account)).to be_empty
  end

  it 'rolls back lead creation when the requested ERP binding fails' do
    conversation.update!(custom_attributes: { 'nico_assistance' => {
                           'status' => 'pending', 'agent_key' => 'comercial', 'intent' => 'comercial', 'cnpj' => '28240080000171'
                         } })
    allow(JrcNico::ErpContext).to receive(:account_allowed?).with(account).and_return(true)
    JrcNico::ErpSetting.create!(account: account, mode: 'live')
    client = instance_double(JrcNico::ErpClient)
    allow(JrcNico::ErpClient).to receive(:new).and_return(client)
    allow(client).to receive(:call).and_raise(JrcNico::ErpClient::Error)
    expect { post path, params: input.merge(bind_erp: true), headers: headers, as: :json }.not_to change(JrcCrm::Lead, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JrcNico::Run.where(account: account)).to be_empty
  end
end
