class CreateJrcCrmLeads < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_leads do |t|
      t.integer :account_id, null: false
      t.integer :owner_id, null: false
      t.integer :contact_id
      t.integer :conversation_id
      t.bigint :team_id
      t.string :name, null: false
      t.string :company_name
      t.string :email
      t.string :phone
      t.string :source
      t.string :temperature, default: 'warm', null: false
      t.string :status, default: 'new'
      t.integer :score, default: 0
      t.text :notes
      t.jsonb :custom_attributes
      t.datetime :converted_at
      t.timestamps null: false
    end
    add_index :jrc_crm_leads, :account_id
    add_index :jrc_crm_leads, :owner_id
    add_index :jrc_crm_leads, :contact_id
    add_index :jrc_crm_leads, :conversation_id
    add_index :jrc_crm_leads, :team_id
    add_index :jrc_crm_leads, :status
    add_index :jrc_crm_leads, :email
    add_index :jrc_crm_leads, :phone
  end
end
