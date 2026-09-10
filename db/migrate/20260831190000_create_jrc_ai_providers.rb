class CreateJrcAiProviders < ActiveRecord::Migration[7.1]
  def change
    create_table :jrc_ai_providers do |t|
      t.references :account, null: false, foreign_key: true
      t.references :created_by, null: true, foreign_key: { to_table: :users }
      t.string :provider_type, null: false
      t.string :name, null: false
      t.text :api_key
      t.string :base_url
      t.string :default_model
      t.string :fast_model
      t.string :advanced_model
      t.bigint :monthly_token_limit
      t.bigint :monthly_budget_cents
      t.boolean :active, null: false, default: true
      t.boolean :default_provider, null: false, default: false
      t.string :status, null: false, default: 'not_validated'
      t.datetime :last_validated_at
      t.text :last_error
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end

    add_index :jrc_ai_providers, [:account_id, :name], unique: true
    add_index :jrc_ai_providers, :account_id, unique: true,
              where: 'default_provider = true', name: 'idx_jrc_ai_one_default_provider_per_account'
  end
end
