class CreateJrcCrmOrganizations < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_organizations do |t|
      t.integer :account_id, null: false
      t.integer :owner_id
      t.string :name, null: false
      t.string :domain
      t.string :phone
      t.string :website
      t.text :description
      t.boolean :active, default: true, null: false
      t.jsonb :custom_attributes, default: {}
      t.timestamps null: false
    end

    add_index :jrc_crm_organizations, :account_id
    add_index :jrc_crm_organizations, :owner_id
    add_index :jrc_crm_organizations, :name
    add_index :jrc_crm_organizations, :active
  end
end
