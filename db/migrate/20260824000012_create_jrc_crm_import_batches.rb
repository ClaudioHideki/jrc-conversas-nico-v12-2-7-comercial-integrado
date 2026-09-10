class CreateJrcCrmImportBatches < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_import_batches do |t|
      t.integer :account_id, null: false
      t.integer :user_id
      t.string :file_name
      t.string :import_type, default: 'leads'
      t.integer :row_count
      t.integer :success_count, default: 0
      t.integer :error_count, default: 0
      t.integer :duplicate_count, default: 0
      t.string :status, default: 'pending'
      t.timestamps null: false
    end
    add_index :jrc_crm_import_batches, :account_id
    add_index :jrc_crm_import_batches, :user_id
    add_index :jrc_crm_import_batches, :status

    create_table :jrc_crm_import_row_errors do |t|
      t.bigint :batch_id
      t.integer :row_number
      t.jsonb :row_data
      t.text :error_message
      t.datetime :created_at, null: false
    end
    add_index :jrc_crm_import_row_errors, :batch_id
  end
end
