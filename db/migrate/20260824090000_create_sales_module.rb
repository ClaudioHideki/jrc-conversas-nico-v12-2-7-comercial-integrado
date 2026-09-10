class CreateSalesModule < ActiveRecord::Migration[7.0]
  def change
    create_table :sales_pipelines do |t|
      t.references :account, null: false, type: :integer, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :sales_pipelines, [:account_id, :name], unique: true

    create_table :sales_stages do |t|
      t.references :account, null: false, type: :integer, foreign_key: true
      t.references :sales_pipeline, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false
      t.string :color, null: false
      t.string :stage_type, null: false, default: 'open'
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :sales_stages, [:sales_pipeline_id, :name], unique: true
    add_index :sales_stages, [:sales_pipeline_id, :position], unique: true

    create_table :sales_loss_reasons do |t|
      t.references :account, null: false, type: :integer, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :sales_loss_reasons, [:account_id, :name], unique: true

    create_table :sales_opportunities do |t|
      t.references :account, null: false, type: :integer, foreign_key: true
      t.references :sales_pipeline, null: false, foreign_key: true
      t.references :sales_stage, null: false, foreign_key: true
      t.references :contact, null: false, type: :integer, foreign_key: true
      t.references :conversation, type: :integer, foreign_key: true
      t.references :inbox, type: :integer, foreign_key: true
      t.references :team, foreign_key: true
      t.references :owner, null: false, type: :integer, foreign_key: { to_table: :users }
      t.references :loss_reason, foreign_key: { to_table: :sales_loss_reasons }
      t.string :title, null: false
      t.string :product_name
      t.decimal :value, precision: 15, scale: 2
      t.string :temperature, null: false, default: 'warm'
      t.string :source_channel
      t.string :status, null: false, default: 'open'
      t.text :notes
      t.text :loss_notes
      t.datetime :won_at
      t.datetime :lost_at
      t.datetime :archived_at
      t.string :idempotency_key
      t.timestamps
    end
    add_index :sales_opportunities, [:account_id, :owner_id]
    add_index :sales_opportunities, [:account_id, :contact_id]
    add_index :sales_opportunities, [:account_id, :conversation_id]
    add_index :sales_opportunities, [:account_id, :sales_stage_id]
    add_index :sales_opportunities, [:account_id, :status]
    add_index :sales_opportunities, [:account_id, :idempotency_key], unique: true,
              where: 'idempotency_key IS NOT NULL'

    create_table :sales_activities do |t|
      t.references :account, null: false, type: :integer, foreign_key: true
      t.references :sales_opportunity, null: false, foreign_key: true
      t.references :contact, null: false, type: :integer, foreign_key: true
      t.references :owner, null: false, type: :integer, foreign_key: { to_table: :users }
      t.string :activity_type, null: false
      t.string :title, null: false
      t.datetime :scheduled_at, null: false
      t.string :status, null: false, default: 'scheduled'
      t.text :notes
      t.datetime :completed_at
      t.timestamps
    end
    add_index :sales_activities, [:account_id, :owner_id]
    add_index :sales_activities, [:account_id, :scheduled_at]
    add_index :sales_activities, [:account_id, :status]

    create_table :sales_stage_histories do |t|
      t.references :account, null: false, type: :integer, foreign_key: true
      t.references :sales_opportunity, null: false, foreign_key: true
      t.references :from_stage, foreign_key: { to_table: :sales_stages }
      t.references :to_stage, null: false, foreign_key: { to_table: :sales_stages }
      t.references :user, null: false, type: :integer, foreign_key: true
      t.datetime :changed_at, null: false
      t.timestamps
    end
    add_index :sales_stage_histories, [:account_id, :sales_opportunity_id], name: 'index_sales_stage_histories_on_account_and_opportunity'
  end
end
