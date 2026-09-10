class CreateJrcCrmPipelinesAndStages < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_pipelines do |t|
      t.integer :account_id, null: false
      t.string :name, null: false
      t.string :key, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, null: false
      t.jsonb :settings, default: {}, null: false
      t.timestamps null: false
    end
    add_index :jrc_crm_pipelines, [:account_id, :key], unique: true

    create_table :jrc_crm_stages do |t|
      t.integer :account_id, null: false
      t.bigint :pipeline_id, null: false
      t.string :name, null: false
      t.string :key, null: false
      t.integer :position, null: false
      t.string :color
      t.decimal :probability, precision: 5, scale: 2
      t.boolean :is_terminal, default: false, null: false
      t.boolean :is_won, default: false, null: false
      t.boolean :is_lost, default: false, null: false
      t.boolean :requires_handoff, default: false, null: false
      t.boolean :active, default: true, null: false
      t.jsonb :settings, default: {}, null: false
      t.timestamps null: false
    end
    add_index :jrc_crm_stages, :account_id
    add_index :jrc_crm_stages, [:pipeline_id, :key], unique: true
  end
end
