class CreateVideoConferenceSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :video_conference_settings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :moderator_url
      t.text :spectator_url
      t.timestamps
    end

    add_index :video_conference_settings, [:account_id, :user_id], unique: true
  end
end
