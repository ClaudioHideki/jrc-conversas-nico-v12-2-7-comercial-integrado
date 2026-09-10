class CreateJrcCrmProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_products do |t|
      t.integer :account_id, null: false
      t.string :name, null: false
      t.string :sku
      t.string :category
      t.text :description
      t.bigint :unit_price_cents, default: 0
      t.string :currency, default: 'BRL'
      t.boolean :active, default: true, null: false
      t.jsonb :metadata, default: {}, null: false
      t.jsonb :custom_attributes, default: {}, null: false
      t.timestamps null: false
    end
    add_index :jrc_crm_products, :account_id
  end
end
