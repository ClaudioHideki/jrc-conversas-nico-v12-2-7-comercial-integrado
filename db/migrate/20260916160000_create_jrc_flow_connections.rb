class CreateJrcFlowConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :jrc_flow_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.string :public_id, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :base_url, null: false
      t.bigint :remote_account_id, null: false
      t.bigint :bot_id
      t.bigint :dashboard_app_id
      t.boolean :enabled, null: false, default: false
      t.jsonb :inbox_ids, null: false, default: []
      t.jsonb :catalog, null: false, default: {}
      t.text :credential_ciphertext
      t.datetime :verified_at
      t.timestamps
    end
    add_index :jrc_flow_connections, [:account_id, :base_url, :remote_account_id], unique: true, name: 'idx_jrc_connection_destination'
    add_reference :jrc_flows, :connection, foreign_key: { to_table: :jrc_flow_connections }
    create_table :jrc_flow_remote_sessions do |t|
      t.references :connection, null: false, foreign_key: { to_table: :jrc_flow_connections }
      t.references :flow, null: false, foreign_key: { to_table: :jrc_flows }
      t.bigint :conversation_id, null: false
      t.bigint :inbox_id, null: false
      t.integer :flow_version, null: false
      t.string :status, null: false, default: 'ready'
      t.string :node_id
      t.jsonb :variables, null: false, default: {}
      t.jsonb :trace, null: false, default: []
      t.integer :steps, null: false, default: 0
      t.bigint :last_message_id, null: false, default: 0
      t.datetime :wake_at
      t.datetime :claimed_at
      t.datetime :finished_at
      t.string :error
      t.timestamps
    end
    add_index :jrc_flow_remote_sessions, [:connection_id, :conversation_id], unique: true, name: 'idx_jrc_remote_session_identity'
    create_table :jrc_flow_remote_events do |t|
      t.references :connection, null: false, foreign_key: { to_table: :jrc_flow_connections }
      t.string :event_key, null: false
      t.text :payload_ciphertext, null: false
      t.string :status, null: false, default: 'queued'
      t.datetime :claimed_at
      t.string :error
      t.timestamps
    end
    add_index :jrc_flow_remote_events, [:connection_id, :event_key], unique: true, name: 'idx_jrc_remote_event_dedup'
    add_index :jrc_flow_remote_events, [:status, :created_at]
  end
end
