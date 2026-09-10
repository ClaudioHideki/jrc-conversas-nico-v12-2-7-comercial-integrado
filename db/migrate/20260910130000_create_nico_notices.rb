class CreateNicoNotices < ActiveRecord::Migration[7.1]
  def change
    create_table :jrc_nico_notices do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, foreign_key: { on_delete: :cascade }
      t.string :event_key, null: false
      t.string :kind, null: false
      t.string :status, null: false, default: 'new'
      t.text :body, null: false
      t.text :request
      t.jsonb :metadata, null: false, default: {}
      t.datetime :read_at
      t.timestamps
    end
    add_index :jrc_nico_notices, [:account_id, :user_id, :event_key], unique: true, name: 'nico_notice_event_once'
    add_reference :jrc_nico_commands, :source_notice, foreign_key: { to_table: :jrc_nico_notices, on_delete: :nullify }
  end
end

