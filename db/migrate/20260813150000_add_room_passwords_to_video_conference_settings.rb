class AddRoomPasswordsToVideoConferenceSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :video_conference_settings, :moderator_password, :text
    add_column :video_conference_settings, :spectator_password, :text
  end
end
