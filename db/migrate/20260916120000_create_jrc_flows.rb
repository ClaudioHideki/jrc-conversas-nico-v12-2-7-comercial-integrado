class CreateJrcFlows < ActiveRecord::Migration[7.1]
  def change
    create_table :jrc_flows do |t|
      t.references :account, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :name, null: false
      t.text :description
      t.string :kind, null: false, default: 'chatbot'
      t.string :status, null: false, default: 'draft'
      t.datetime :next_run_at
      t.jsonb :graph, null: false, default: {}
      t.jsonb :settings, null: false, default: {}
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :jrc_flows, [:account_id, :status]
    create_table :jrc_flow_runs do |t|
      t.references :flow, null: false, foreign_key: { to_table: :jrc_flows }
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.string :event_key, null: false
      t.string :status, null: false, default: 'running'
      t.string :node_id
      t.jsonb :graph, null: false, default: {}
      t.jsonb :settings, null: false, default: {}
      t.jsonb :variables, null: false, default: {}
      t.jsonb :trace, null: false, default: []
      t.bigint :last_message_id, null: false, default: 0
      t.integer :steps, null: false, default: 0
      t.integer :wake_version, null: false, default: 0
      t.datetime :wake_at
      t.datetime :finished_at
      t.datetime :reset_at
      t.string :error
      t.timestamps
    end
    add_index :jrc_flow_runs, [:flow_id, :event_key], unique: true
    add_index :jrc_flow_runs, :conversation_id, unique: true,
              where: "status IN ('running', 'waiting', 'delayed')", name: 'idx_jrc_one_live_flow_per_conversation'
    add_index :jrc_flow_runs, [:account_id, :created_at]
    add_index :jrc_flow_runs, [:status, :wake_at]
  end
end
