class CreateJrcCrmCampaignsAndCustomAttributes < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_campaigns do |t|
      t.integer :account_id, null: false
      t.string :name
      t.text :description
      t.string :status, default: 'active'
      t.bigint :pipeline_id
      t.jsonb :settings
      t.timestamps null: false
    end
    add_index :jrc_crm_campaigns, :account_id
    add_index :jrc_crm_campaigns, :status

    create_table :jrc_crm_custom_attribute_definitions do |t|
      t.integer :account_id, null: false
      t.string :entity_type
      t.string :name
      t.string :key
      t.string :attribute_type
      t.jsonb :options
      t.boolean :required, default: false
      t.boolean :active, default: true
      t.integer :position
      t.timestamps null: false
    end
    add_index :jrc_crm_custom_attribute_definitions, :account_id
    add_index :jrc_crm_custom_attribute_definitions, [:account_id, :entity_type],
              name: 'idx_jrc_crm_custom_attrs_account_entity'
  end
end
