require 'rails_helper'

RSpec.describe 'Super Admin account impersonations', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  before do
    sign_in(super_admin, scope: :super_admin)
    allow_any_instance_of(User).to receive(:generate_sso_auth_token) # rubocop:disable RSpec/AnyInstance
      .with(impersonation: true)
      .and_return('sso-token')
  end

  it 'redirects to the requested settings target for the selected account' do
    administrator

    get "/super_admin/accounts/#{account.id}/impersonate",
        params: { target: "/app/accounts/#{account.id}/settings/inboxes/list" }

    expect(response).to have_http_status(:redirect)
    redirect_uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(redirect_uri.query)

    expect("#{redirect_uri.path}?#{redirect_uri.query}").to include('/app/login')
    expect(query['email']).to eq(administrator.email)
    expect(query['sso_auth_token']).to eq('sso-token')
    expect(query['impersonation']).to eq('true')
    expect(query['target']).to eq("/app/accounts/#{account.id}/settings/inboxes/list")
    expect(query['super_admin_account_id']).to eq(account.id.to_s)
    expect(query['super_admin_return_to']).to eq("/super_admin?account_id=#{account.id}")
  end

  it 'falls back to the selected account settings when target belongs to another account' do
    administrator
    other_account = create(:account)

    get "/super_admin/accounts/#{account.id}/impersonate",
        params: { target: "/app/accounts/#{other_account.id}/settings/inboxes/list" }

    query = Rack::Utils.parse_query(URI.parse(response.location).query)
    expect(query['target']).to eq("/app/accounts/#{account.id}/settings/general")
  end

  it 'shows an alert when the account has no administrator' do
    get "/super_admin/accounts/#{account.id}/impersonate",
        params: { target: "/app/accounts/#{account.id}/settings/general" }

    expect(response).to redirect_to(super_admin_account_path(account))
    expect(flash[:alert]).to eq('Esta conta nao possui administrador para impersonation.')
  end
end
