class ExpandJrcCampaignsForDispatcher < ActiveRecord::Migration[7.1]
  def change
    change_table :jrc_campaigns, bulk: true do |t|
      t.string :rotation_mode, null: false, default: 'round_robin'
      t.integer :delay_min_seconds, null: false, default: 5
      t.integer :delay_max_seconds, null: false, default: 20
      t.jsonb :sending_window, null: false, default: { start: '08:00', end: '18:00', days: [1, 2, 3, 4, 5] }
      t.string :conversation_mode, null: false, default: 'reply_only'
      t.jsonb :recurrence_config, null: false, default: {}
      t.jsonb :follow_up_config, null: false, default: {}
      t.integer :delivered_count, null: false, default: 0
      t.integer :read_count, null: false, default: 0
      t.integer :clicked_count, null: false, default: 0
      t.datetime :last_execution_at
      t.text :last_error
    end

    create_table :jrc_campaign_inboxes do |t|
      t.references :campaign, null: false, foreign_key: { to_table: :jrc_campaigns }
      t.references :inbox, null: false, type: :integer, foreign_key: true
      t.integer :position, null: false, default: 0
      t.integer :weight, null: false, default: 1
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :jrc_campaign_inboxes, [:campaign_id, :inbox_id], unique: true

    create_table :jrc_campaign_steps do |t|
      t.references :campaign, null: false, foreign_key: { to_table: :jrc_campaigns }
      t.integer :position, null: false, default: 0
      t.string :kind, null: false, default: 'text'
      t.text :body, null: false, default: ''
      t.string :media_url
      t.string :file_name
      t.string :template_name
      t.string :template_namespace
      t.string :template_language
      t.jsonb :template_params, null: false, default: {}
      t.jsonb :inbox_overrides, null: false, default: {}
      t.integer :delay_after_seconds, null: false, default: 0
      t.boolean :only_if_no_reply, null: false, default: false
      t.integer :follow_up_after_hours
      t.timestamps
    end
    add_index :jrc_campaign_steps, [:campaign_id, :position]

    create_table :jrc_campaign_executions do |t|
      t.references :campaign, null: false, foreign_key: { to_table: :jrc_campaigns }
      t.integer :run_number, null: false, default: 1
      t.string :status, null: false, default: 'queued'
      t.integer :total_count, null: false, default: 0
      t.integer :sent_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.integer :delivered_count, null: false, default: 0
      t.integer :read_count, null: false, default: 0
      t.integer :replied_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :jrc_campaign_executions, [:campaign_id, :run_number], unique: true

    create_table :jrc_campaign_recipients do |t|
      t.references :campaign, null: false, foreign_key: { to_table: :jrc_campaigns }
      t.references :execution, null: false, foreign_key: { to_table: :jrc_campaign_executions }
      t.references :contact, type: :integer, foreign_key: true
      t.references :inbox, type: :integer, foreign_key: true
      t.references :conversation, type: :integer, foreign_key: true
      t.string :name
      t.string :phone_number, null: false
      t.string :source, null: false, default: 'contact'
      t.string :status, null: false, default: 'queued'
      t.datetime :scheduled_at
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :read_at
      t.datetime :replied_at
      t.datetime :failed_at
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :jrc_campaign_recipients, [:execution_id, :status]
    add_index :jrc_campaign_recipients, [:execution_id, :phone_number], unique: true
    add_index :jrc_campaign_recipients, [:campaign_id, :phone_number]

    create_table :jrc_campaign_deliveries do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :jrc_campaign_recipients }
      t.references :step, null: false, foreign_key: { to_table: :jrc_campaign_steps }
      t.references :inbox, null: false, type: :integer, foreign_key: true
      t.string :external_id
      t.string :status, null: false, default: 'queued'
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :read_at
      t.datetime :failed_at
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :jrc_campaign_deliveries, :external_id, unique: true, where: 'external_id IS NOT NULL'
    add_index :jrc_campaign_deliveries, [:recipient_id, :step_id], unique: true

    create_table :jrc_campaign_events do |t|
      t.references :campaign, null: false, foreign_key: { to_table: :jrc_campaigns }
      t.references :execution, foreign_key: { to_table: :jrc_campaign_executions }
      t.references :recipient, foreign_key: { to_table: :jrc_campaign_recipients }
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :jrc_campaign_events, [:campaign_id, :event_type]

    create_table :jrc_campaign_blacklists do |t|
      t.references :account, null: false, type: :integer, foreign_key: true
      t.references :created_by, type: :integer, foreign_key: { to_table: :users }
      t.string :phone_number, null: false
      t.string :reason
      t.string :source, null: false, default: 'manual'
      t.timestamps
    end
    add_index :jrc_campaign_blacklists, [:account_id, :phone_number], unique: true

    create_table :jrc_campaign_sanitized_lists do |t|
      t.references :account, null: false, type: :integer, foreign_key: true
      t.references :created_by, type: :integer, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.jsonb :stats, null: false, default: {}
      t.timestamps
    end

    create_table :jrc_campaign_sanitized_entries do |t|
      t.references :sanitized_list, null: false, foreign_key: { to_table: :jrc_campaign_sanitized_lists }
      t.string :name
      t.string :phone_number
      t.string :normalized_phone
      t.string :status, null: false, default: 'valid'
      t.string :reason
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :jrc_campaign_sanitized_entries, [:sanitized_list_id, :status]
    add_index :jrc_campaign_sanitized_entries, [:sanitized_list_id, :normalized_phone]

    create_table :jrc_campaign_media_assets do |t|
      t.references :account, null: false, type: :integer, foreign_key: true
      t.references :created_by, type: :integer, foreign_key: { to_table: :users }
      t.string :kind
      t.timestamps
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          INSERT INTO jrc_campaign_steps (
            campaign_id, position, kind, body, delay_after_seconds, only_if_no_reply,
            template_params, inbox_overrides, created_at, updated_at
          )
          SELECT id, 0, 'text', message_body, 0, FALSE, '{}'::jsonb, '{}'::jsonb, NOW(), NOW()
          FROM jrc_campaigns
          WHERE COALESCE(message_body, '') <> ''
            AND NOT EXISTS (SELECT 1 FROM jrc_campaign_steps WHERE jrc_campaign_steps.campaign_id = jrc_campaigns.id)
        SQL

        execute <<~SQL.squish
          UPDATE jrc_campaigns
          SET status = 'draft',
              paused_at = NULL,
              started_at = NULL,
              last_error = 'Campanha migrada da versão anterior. Revise as caixas, mensagens e agendamento antes de iniciar.',
              updated_at = NOW()
          WHERE status IN ('scheduled', 'running', 'paused')
        SQL
      end
    end
  end
end
