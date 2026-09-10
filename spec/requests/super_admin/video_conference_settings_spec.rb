require 'rails_helper'

RSpec.describe 'Super Admin video conference settings', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:path) { super_admin_video_conference_setting_path(agent, account_id: account.id) }

  before { sign_in(super_admin, scope: :super_admin) }

  it 'creates and persists a setting for an agent' do
    expect do
      patch path, params: {
        video_conference_setting: {
          moderator_url: 'https://meet.example.com/moderator/original',
          spectator_url: 'https://meet.example.com/spectator/original',
          moderator_password: 'moderator-secret',
          spectator_password: 'spectator-secret'
        }
      }
    end.to change(VideoConferenceSetting, :count).by(1)

    setting = VideoConferenceSetting.last
    expect(setting).to have_attributes(
      account_id: account.id,
      user_id: agent.id,
      moderator_url: 'https://meet.example.com/moderator/original',
      spectator_url: 'https://meet.example.com/spectator/original',
      moderator_password: 'moderator-secret',
      spectator_password: 'spectator-secret'
    )
    expect(response).to redirect_to(super_admin_video_conference_settings_path(account_id: account.id, user_id: agent.id))
  end

  it 'edits the existing setting without creating another record' do
    setting = create(:video_conference_setting, account: account, user: agent)

    expect do
      patch path, params: {
        video_conference_setting: {
          moderator_url: 'https://meet.example.com/moderator/updated',
          spectator_url: '',
          moderator_password: '',
          spectator_password: ''
        }
      }
    end.not_to change(VideoConferenceSetting, :count)

    expect(setting.reload).to have_attributes(
      moderator_url: 'https://meet.example.com/moderator/updated',
      spectator_url: '',
      moderator_password: 'moderator-room-password',
      spectator_password: 'spectator-room-password'
    )
  end

  it 'rejects an invalid URL without changing the persisted setting' do
    setting = create(:video_conference_setting, account: account, user: agent)

    patch path, params: {
      video_conference_setting: { moderator_url: 'javascript:alert(1)', spectator_url: '' }
    }

    expect(setting.reload.moderator_url).to eq('https://meet.example.com/moderator/room-1')
    expect(response).to redirect_to(super_admin_video_conference_settings_path(account_id: account.id, user_id: agent.id))
  end
end
