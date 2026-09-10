class CreateJrcCrmLostReasons < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_lost_reasons do |t|
      t.integer :account_id, null: false
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.timestamps null: false
    end
    add_index :jrc_crm_lost_reasons, [:account_id, :name], unique: true
  end
end
