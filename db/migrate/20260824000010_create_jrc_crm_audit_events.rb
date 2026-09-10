class CreateJrcCrmAuditEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_audit_events do |t|
      t.integer :account_id, null: false
      t.string :event_type
      t.string :actor_type
      t.integer :actor_id
      t.string :resource_type
      t.bigint :resource_id
      t.jsonb :from_value
      t.jsonb :to_value
      t.jsonb :metadata
      t.string :ip_address
      t.datetime :created_at, null: false
    end
    add_index :jrc_crm_audit_events, :account_id
    add_index :jrc_crm_audit_events, :event_type
    add_index :jrc_crm_audit_events, [:resource_type, :resource_id]
    add_index :jrc_crm_audit_events, :actor_id
    add_index :jrc_crm_audit_events, :created_at
  end
end
