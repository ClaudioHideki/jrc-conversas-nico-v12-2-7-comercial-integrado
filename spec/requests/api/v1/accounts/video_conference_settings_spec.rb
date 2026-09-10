require 'rails_helper'

RSpec.describe 'Video Conference Settings API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:headers) { agent.create_new_auth_token }
  let(:base_path) { "/api/v1/accounts/#{account.id}/video_conference_settings" }

  it 'returns only the authenticated agent URLs and room passwords' do
    create(:video_conference_setting,
           account: account,
           user: agent,
           moderator_url: 'https://meet.example.com/moderator/mine',
           spectator_url: nil,
           moderator_password: 'my-moderator-password',
           spectator_password: nil)
    create(:video_conference_setting,
           account: account,
           user: other_agent,
           moderator_url: 'https://meet.example.com/moderator/other',
           spectator_url: 'https://meet.example.com/spectator/other',
           moderator_password: 'other-moderator-password',
           spectator_password: 'other-spectator-password')

    get "#{base_path}/me", headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.headers['Cache-Control']).to eq('no-store')
    expect(response.parsed_body).to eq(
      'configured' => true,
      'moderator_url' => 'https://meet.example.com/moderator/mine',
      'spectator_url' => nil,
      'moderator_password' => 'my-moderator-password',
      'spectator_password' => nil
    )
    expect(response.body).not_to include('/other')
    expect(response.body).not_to include('other-moderator-password')
    expect(response.body).not_to include('other-spectator-password')
  end

  it 'does not expose a stored password when its corresponding role URL is absent' do
    create(:video_conference_setting,
           account: account,
           user: agent,
           moderator_url: nil,
           spectator_url: 'https://meet.example.com/spectator/mine',
           moderator_password: 'inactive-moderator-password',
           spectator_password: 'active-spectator-password')

    get "#{base_path}/me", headers: headers, as: :json

    expect(response.parsed_body).to include(
      'moderator_url' => nil,
      'moderator_password' => nil,
      'spectator_url' => 'https://meet.example.com/spectator/mine',
      'spectator_password' => 'active-spectator-password'
    )
    expect(response.body).not_to include('inactive-moderator-password')
  end

  it 'reports configured for moderator-only, spectator-only, and both URL combinations' do
    setting = create(:video_conference_setting, account: account, user: agent, spectator_url: nil)

    get "#{base_path}/me", headers: headers, as: :json
    expect(response.parsed_body['configured']).to be(true)

    setting.update!(moderator_url: nil, spectator_url: 'https://meet.example.com/spectator/mine')
    get "#{base_path}/me", headers: headers, as: :json
    expect(response.parsed_body['configured']).to be(true)

    setting.update!(moderator_url: 'https://meet.example.com/moderator/mine')
    get "#{base_path}/me", headers: headers, as: :json
    expect(response.parsed_body['configured']).to be(true)
  end

  it 'reports unconfigured after both URLs are erased' do
    setting = create(:video_conference_setting, account: account, user: agent)
    setting.update!(moderator_url: '', spectator_url: '')

    get "#{base_path}/me", headers: headers, as: :json

    expect(response.parsed_body).to eq(
      'configured' => false,
      'moderator_url' => nil,
      'spectator_url' => nil,
      'moderator_password' => nil,
      'spectator_password' => nil
    )
  end

  it 'does not let an agent list or edit video conference settings' do
    setting = create(:video_conference_setting, account: account, user: other_agent)

    get base_path, headers: headers, as: :json
    expect(response).to have_http_status(:forbidden)

    patch "#{base_path}/#{other_agent.id}",
          params: { video_conference_setting: { moderator_url: 'https://meet.example.com/attacker' } },
          headers: headers,
          as: :json

    expect(response).to have_http_status(:forbidden)
    expect(setting.reload.moderator_url).to eq('https://meet.example.com/moderator/room-1')
  end

  it 'isolates settings between agents' do
    create(:video_conference_setting, account: account, user: other_agent)

    get "#{base_path}/me", headers: headers, as: :json

    expect(response.parsed_body['configured']).to be(false)
  end
end
