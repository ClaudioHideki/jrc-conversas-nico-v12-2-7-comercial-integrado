class CreateJrcCampaigns < ActiveRecord::Migration[7.1]
  def change
    create_table :jrc_campaigns do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :status, null: false, default: 'draft'
      t.string :trigger_type, null: false, default: 'manual'
      t.datetime :scheduled_at
      t.string :audience_type, null: false, default: 'all_contacts'
      t.jsonb :audience_config, null: false, default: {}
      t.text :message_body, null: false, default: ''
      t.jsonb :metadata, null: false, default: {}
      t.datetime :started_at
      t.datetime :paused_at
      t.datetime :completed_at
      t.integer :estimated_recipients, null: false, default: 0
      t.integer :sent_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.integer :replied_count, null: false, default: 0
      t.timestamps
    end

    add_index :jrc_campaigns, [:account_id, :status]
    add_index :jrc_campaigns, [:account_id, :scheduled_at]
  end
end
