class CreateNicoErpConfiguration < ActiveRecord::Migration[7.1]
  def change
    create_table :jrc_nico_erp_settings do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :mode, null: false, default: 'off'
      t.string :operator_company_id
      t.string :requester_user_id
      t.timestamps
    end
    create_table :jrc_nico_erp_bindings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.string :cnpj, null: false
      t.string :customer_name, null: false
      t.string :bemtevi_customer_id, null: false
      t.string :helpdesk_company_id, null: false
      t.string :mode, null: false
      t.string :version, null: false
      t.boolean :enabled, null: false, default: true
      t.references :verified_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :jrc_nico_erp_bindings, [:account_id, :contact_id], unique: true, name: 'nico_erp_contact_unique'
  end
end
