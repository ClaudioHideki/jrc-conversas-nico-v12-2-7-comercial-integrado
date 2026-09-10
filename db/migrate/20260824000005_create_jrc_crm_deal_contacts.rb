class CreateJrcCrmDealContacts < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_deal_contacts do |t|
      t.bigint :deal_id, null: false
      t.integer :contact_id, null: false
      t.string :role, default: 'primary'
      t.timestamps null: false
    end
    add_index :jrc_crm_deal_contacts, [:deal_id, :contact_id], unique: true
  end
end
