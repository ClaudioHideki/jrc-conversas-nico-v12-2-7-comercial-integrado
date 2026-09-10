require 'rails_helper'

RSpec.describe 'Super Admin account settings', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account) }

  describe 'authorization' do
    it 'allows an authenticated SuperAdmin to access account settings' do
      sign_in(super_admin, scope: :super_admin)

      get "/super_admin/accounts/#{account.id}/settings/general"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Configurações da Conta')
      expect(response.body).to include(account.name)
    end

    it 'does not allow a common user to access SuperAdmin account settings' do
      user = create(:user, account: account)
      sign_in(user, scope: :user)

      get "/super_admin/accounts/#{account.id}/settings/general"

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('/super_admin/sign_in')
    end

    it 'does not allow an account administrator user to access SuperAdmin account settings' do
      admin = create(:user, account: account, role: :administrator)
      sign_in(admin, scope: :user)

      get "/super_admin/accounts/#{account.id}/settings/agents"

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('/super_admin/sign_in')
    end

    it 'redirects with an alert when account does not exist' do
      sign_in(super_admin, scope: :super_admin)

      get '/super_admin/accounts/999999/settings/general'

      expect(response).to redirect_to(super_admin_root_path)
      expect(flash[:alert]).to eq('Conta nao encontrada.')
    end
  end

  describe 'account context' do
    it 'loads data only for the selected account' do
      other_account = create(:account)
      create(:label, account: account, title: 'alpha')
      create(:label, account: other_account, title: 'beta')
      sign_in(super_admin, scope: :super_admin)

      get "/super_admin/accounts/#{account.id}/settings/labels"

      expect(response.body).to include('alpha')
      expect(response.body).not_to include('beta')

      get "/super_admin/accounts/#{other_account.id}/settings/labels"

      expect(response.body).to include('beta')
      expect(response.body).not_to include('alpha')
    end

    it 'does not alter another account when creating a label' do
      other_account = create(:account)
      sign_in(super_admin, scope: :super_admin)

      post "/super_admin/accounts/#{account.id}/settings/labels/label",
           params: { label: { title: 'financeiro', color: '#1f93ff', description: 'Financeiro' } }

      expect(account.labels.find_by(title: 'financeiro')).to be_present
      expect(other_account.labels.find_by(title: 'financeiro')).to be_nil
    end
  end

  describe 'inboxes' do
    before do
      sign_in(super_admin, scope: :super_admin)
    end

    it 'lists inboxes for the selected account' do
      channel = account.api_channels.create!
      account.inboxes.create!(name: 'API Principal', channel: channel)

      get "/super_admin/accounts/#{account.id}/settings/inboxes"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('API Principal')
    end

    it 'creates, updates and deletes an API inbox for the selected account' do
      post "/super_admin/accounts/#{account.id}/settings/inboxes/inbox",
           params: {
             inbox: { name: 'Nova API', channel_type: 'api', timezone: 'UTC' },
             channel: { webhook_url: 'https://example.com/hook', hmac_mandatory: '0' }
           }

      inbox = account.inboxes.find_by!(name: 'Nova API')
      expect(inbox.channel).to be_a(Channel::Api)
      expect(inbox.channel.webhook_url).to eq('https://example.com/hook')

      patch "/super_admin/accounts/#{account.id}/settings/inboxes/inbox/#{inbox.id}",
            params: {
              inbox: { name: 'API Atualizada', timezone: 'UTC', enable_auto_assignment: '1', greeting_enabled: '0' },
              channel: { webhook_url: 'https://example.com/updated', hmac_mandatory: '1' }
            }

      expect(inbox.reload.name).to eq('API Atualizada')
      expect(inbox.channel.reload.webhook_url).to eq('https://example.com/updated')

      delete "/super_admin/accounts/#{account.id}/settings/inboxes/inbox/#{inbox.id}"

      expect(account.inboxes.find_by(id: inbox.id)).to be_nil
    end
  end

  describe 'existing routes' do
    it 'keeps the normal dashboard route mounted' do
      expect(get: "/app/accounts/#{account.id}/settings/inboxes/list").to route_to('dashboard#index', account_id: account.id.to_s)
    end

    it 'keeps SuperAdmin and User login routes separate' do
      expect(get: '/super_admin/sign_in').to route_to('super_admin/devise/sessions#new')
      expect(get: '/app/login').to route_to('dashboard#index')
    end
  end
end
