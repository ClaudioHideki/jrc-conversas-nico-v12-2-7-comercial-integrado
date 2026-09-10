require 'rails_helper'

RSpec.describe VideoConferenceSetting do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  it 'is configured when only the moderator URL is present' do
    setting = build(:video_conference_setting, account: account, user: agent, spectator_url: nil)

    expect(setting).to be_valid
    expect(setting).to be_configured
  end

  it 'is configured when only the spectator URL is present' do
    setting = build(:video_conference_setting, account: account, user: agent, moderator_url: nil)

    expect(setting).to be_valid
    expect(setting).to be_configured
  end

  it 'is not configured when both URLs are blank' do
    setting = build(:video_conference_setting, account: account, user: agent, moderator_url: '', spectator_url: '')

    expect(setting).to be_valid
    expect(setting).not_to be_configured
  end

  it 'encrypts both room passwords at rest' do
    setting = create(:video_conference_setting, account: account, user: agent)
    stored_setting = described_class.connection.select_one(
      "SELECT moderator_password, spectator_password FROM video_conference_settings WHERE id = #{setting.id}"
    )

    expect(setting.moderator_password).to eq('moderator-room-password')
    expect(setting.spectator_password).to eq('spectator-room-password')
    expect(stored_setting['moderator_password']).not_to include('moderator-room-password')
    expect(stored_setting['spectator_password']).not_to include('spectator-room-password')
  end

  it 'rejects invalid and dangerous URLs' do
    %w[invalid javascript:alert(1) data:text/html,test file:///tmp/test vbscript:msgbox(1)].each do |url|
      setting = build(:video_conference_setting, account: account, user: agent, moderator_url: url)

      expect(setting).not_to be_valid
      expect(setting.errors[:moderator_url]).to be_present
    end
  end

  it 'rejects non-HTTPS URLs' do
    setting = build(:video_conference_setting, account: account, user: agent, moderator_url: 'http://meet.example.com/room')

    expect(setting).not_to be_valid
  end

  it 'keeps one setting per agent and account' do
    create(:video_conference_setting, account: account, user: agent)
    duplicate = build(:video_conference_setting, account: account, user: agent)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to be_present
  end

  it 'does not allow a user from another account' do
    other_agent = create(:user)
    setting = build(:video_conference_setting, account: account, user: other_agent)

    expect(setting).not_to be_valid
    expect(setting.errors[:user]).to be_present
  end
end
