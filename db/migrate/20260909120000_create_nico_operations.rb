class CreateNicoOperations < ActiveRecord::Migration[7.1]
  def change
    create_table :jrc_nico_sessions do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.jsonb :messages, null: false, default: []
      t.jsonb :context, null: false, default: {}
      t.timestamps
    end
    add_index :jrc_nico_sessions, [:account_id, :user_id], unique: true
    create_table :jrc_nico_commands do |t|
      t.references :session, null: false, foreign_key: { to_table: :jrc_nico_sessions, on_delete: :cascade }
      t.uuid :request_id, null: false
      t.text :message, null: false
      t.string :status, null: false, default: 'planning'
      t.string :tool
      t.jsonb :arguments, null: false, default: {}
      t.jsonb :result, null: false, default: {}
      t.text :reply
      t.datetime :approved_at
      t.timestamps
    end
    add_index :jrc_nico_commands, [:session_id, :request_id], unique: true
    create_table :jrc_nico_inferences do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :status, null: false, default: 'running'
      t.integer :reserved_tokens, null: false, default: 0
      t.timestamps
    end
    add_index :jrc_nico_inferences, [:account_id, :created_at]
    create_table :jrc_nico_delegations do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :agent_bot, null: false, foreign_key: true
      t.string :status, null: false, default: 'active'
      t.text :objective, null: false
      t.text :summary
      t.string :reason
      t.integer :version, null: false, default: 1
      t.boolean :allow_crm, null: false, default: false
      t.datetime :expires_at, null: false
      t.bigint :last_message_id, null: false, default: 0
      t.timestamps
    end
    create_table :jrc_nico_turns do |t|
      t.references :delegation, null: false, foreign_key: { to_table: :jrc_nico_delegations, on_delete: :cascade }
      t.bigint :message_id, null: false
      t.integer :version, null: false
      t.string :status, null: false, default: 'running'
      t.bigint :outgoing_message_id
      t.timestamps
    end
    add_index :jrc_nico_turns, [:delegation_id, :version, :message_id], unique: true, name: 'nico_turn_once'
  end
end
