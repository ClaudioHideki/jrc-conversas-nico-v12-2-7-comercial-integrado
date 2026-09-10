class CreateJrcCrmActivitiesAndFollowUps < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_activities do |t|
      t.integer :account_id, null: false
      t.bigint :deal_id
      t.bigint :lead_id
      t.integer :contact_id
      t.bigint :company_id
      t.bigint :organization_id
      t.integer :conversation_id
      t.integer :user_id
      t.string :activity_type
      t.string :title
      t.text :description
      t.datetime :due_at
      t.datetime :completed_at
      t.jsonb :metadata
      t.timestamps null: false
    end
    add_index :jrc_crm_activities, :account_id
    add_index :jrc_crm_activities, :deal_id
    add_index :jrc_crm_activities, :user_id
    add_index :jrc_crm_activities, :organization_id
    add_index :jrc_crm_activities, :due_at
    add_index :jrc_crm_activities, :activity_type

    create_table :jrc_crm_follow_ups do |t|
      t.integer :account_id, null: false
      t.bigint :deal_id
      t.bigint :lead_id
      t.integer :user_id
      t.string :title
      t.text :description
      t.datetime :due_at
      t.boolean :is_completed, default: false
      t.datetime :completed_at
      t.timestamps null: false
    end
    add_index :jrc_crm_follow_ups, :account_id
    add_index :jrc_crm_follow_ups, :deal_id
    add_index :jrc_crm_follow_ups, :user_id
  end
end
