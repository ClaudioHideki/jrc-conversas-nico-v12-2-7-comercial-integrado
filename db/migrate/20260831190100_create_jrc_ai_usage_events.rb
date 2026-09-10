class CreateJrcAiUsageEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :jrc_ai_usage_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :provider, null: true, foreign_key: { to_table: :jrc_ai_providers }
      t.references :user, null: true, foreign_key: true
      t.string :agent_key, null: false, default: 'copilot'
      t.string :feature, null: false, default: 'assistant'
      t.string :model
      t.bigint :input_tokens, null: false, default: 0
      t.bigint :output_tokens, null: false, default: 0
      t.bigint :total_tokens, null: false, default: 0
      t.bigint :estimated_cost_cents, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :jrc_ai_usage_events, [:account_id, :created_at]
    add_index :jrc_ai_usage_events, [:account_id, :agent_key, :created_at], name: 'idx_jrc_ai_usage_by_agent'
  end
end
