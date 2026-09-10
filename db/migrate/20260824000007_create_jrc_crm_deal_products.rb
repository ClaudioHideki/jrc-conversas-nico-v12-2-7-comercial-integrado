class CreateJrcCrmDealProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_deal_products do |t|
      t.bigint :deal_id
      t.bigint :product_id
      t.text :description_snapshot
      t.integer :quantity, default: 1
      t.bigint :unit_price_cents
      t.bigint :discount_cents, default: 0
      t.bigint :total_cents
      t.text :notes
      t.timestamps null: false
    end
    add_index :jrc_crm_deal_products, :deal_id
    add_index :jrc_crm_deal_products, :product_id
  end
end
