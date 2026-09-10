FactoryBot.define do
  factory :video_conference_setting do
    account
    user
    moderator_url { 'https://meet.example.com/moderator/room-1' }
    spectator_url { 'https://meet.example.com/spectator/room-1' }
    moderator_password { 'moderator-room-password' }
    spectator_password { 'spectator-room-password' }
  end
end
