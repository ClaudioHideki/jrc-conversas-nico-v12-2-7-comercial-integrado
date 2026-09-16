class CreateJrcBrokerIntegrationTables < ActiveRecord::Migration[7.1]
  def change
    create_integration_table
    create_binding_table
    create_grant_table
  end

  private

  def create_integration_table
    create_table :jrc_broker_integrations do |t|
      t.references :account, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :broker_origin, null: false
      t.uuid :organization_id, null: false
      t.integer :destination_revision, null: false
      t.text :encrypted_control_key, null: false
      t.timestamps
    end
    add_index :jrc_broker_integrations, [:broker_origin, :organization_id], unique: true, name: 'jrc_broker_remote_org_unique'
    add_check_constraint :jrc_broker_integrations, 'destination_revision > 0', name: 'jrc_broker_revision_positive'
  end

  def create_binding_table
    add_index :inboxes, [:account_id, :id], unique: true, name: 'jrc_broker_inbox_tenant_unique'

    create_table :jrc_broker_inbox_bindings do |t|
      t.bigint :account_id, null: false
      t.bigint :inbox_id, null: false
      t.uuid :integration_id, null: false
      t.uuid :instance_id, null: false
      t.timestamps
    end
    add_index :jrc_broker_inbox_bindings, :inbox_id, unique: true
    add_index :jrc_broker_inbox_bindings, [:account_id, :inbox_id], unique: true, name: 'jrc_broker_binding_tenant_unique'
    add_index :jrc_broker_inbox_bindings, [:account_id, :integration_id], unique: true, name: 'jrc_broker_connection_unique'
    add_foreign_key :jrc_broker_inbox_bindings, :jrc_broker_integrations, column: :account_id, primary_key: :account_id, on_delete: :cascade
    add_foreign_key :jrc_broker_inbox_bindings, :inboxes, column: [:account_id, :inbox_id], primary_key: [:account_id, :id], on_delete: :cascade
  end

  def create_grant_table
    create_table :jrc_broker_inbox_grants do |t|
      t.bigint :account_id, null: false
      t.bigint :inbox_id, null: false
      t.bigint :user_id, null: false
      t.boolean :can_pair, null: false, default: false
      t.timestamps
    end
    add_index :jrc_broker_inbox_grants, [:account_id, :inbox_id, :user_id], unique: true, name: 'jrc_broker_grant_unique'
    add_foreign_key :jrc_broker_inbox_grants, :jrc_broker_inbox_bindings, column: [:account_id, :inbox_id],
                                                                          primary_key: [:account_id, :inbox_id], on_delete: :cascade
    add_foreign_key :jrc_broker_inbox_grants, :account_users, column: [:account_id, :user_id],
                                                              primary_key: [:account_id, :user_id], on_delete: :cascade
    add_foreign_key :jrc_broker_inbox_grants, :inbox_members, column: [:inbox_id, :user_id],
                                                              primary_key: [:inbox_id, :user_id], on_delete: :cascade
  end
end
