class CreateJrcCrmAutomations < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_automation_rules do |t|
      t.integer :account_id, null: false
      t.string :name, null: false
      t.text :description
      t.string :trigger_type, null: false
      t.jsonb :conditions, default: []
      t.jsonb :actions, default: []
      t.boolean :active, default: true, null: false
      t.integer :execution_count, default: 0, null: false
      t.datetime :last_executed_at
      t.timestamps null: false
    end

    add_index :jrc_crm_automation_rules, :account_id
    add_index :jrc_crm_automation_rules, :trigger_type
    add_index :jrc_crm_automation_rules, :active

    create_table :jrc_crm_automation_executions do |t|
      t.integer :account_id, null: false
      t.bigint :automation_rule_id, null: false
      t.string :execution_id, null: false
      t.string :correlation_id, null: false
      t.string :event_type, null: false
      t.integer :depth, default: 0, null: false
      t.string :status, default: 'pending', null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message
      t.jsonb :metadata, default: {}
      t.timestamps null: false
    end

    add_index :jrc_crm_automation_executions, :account_id
    add_index :jrc_crm_automation_executions, :automation_rule_id
    add_index :jrc_crm_automation_executions, :execution_id, unique: true
    add_index :jrc_crm_automation_executions, [:account_id, :correlation_id, :automation_rule_id], name: 'idx_jrc_crm_auto_exec_idempotency'
    add_index :jrc_crm_automation_executions, :status
  end
end
