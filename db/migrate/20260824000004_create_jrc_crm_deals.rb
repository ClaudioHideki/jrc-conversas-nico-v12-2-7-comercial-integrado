class CreateJrcCrmDeals < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_deals do |t|
      t.integer :account_id, null: false
      t.bigint :pipeline_id, null: false
      t.bigint :stage_id, null: false
      t.integer :contact_id
      t.bigint :organization_id
      t.bigint :company_id
      t.integer :owner_id, null: false
      t.bigint :team_id
      t.string :title, null: false
      t.text :description
      t.bigint :value_cents, default: 0, null: false
      t.string :currency, default: 'BRL', null: false
      t.string :source
      t.string :status, default: 'open', null: false
      t.decimal :probability, precision: 5, scale: 2
      t.datetime :expected_close_at
      t.datetime :won_at
      t.datetime :lost_at
      t.bigint :lost_reason_id
      t.text :lost_reason_note
      t.bigint :lead_id
      t.jsonb :custom_attributes, default: {}
      t.jsonb :metadata, default: {}
      t.integer :lock_version, default: 0, null: false
      t.timestamps null: false
    end

    add_index :jrc_crm_deals, :account_id
    add_index :jrc_crm_deals, :pipeline_id
    add_index :jrc_crm_deals, :stage_id
    add_index :jrc_crm_deals, :owner_id
    add_index :jrc_crm_deals, :team_id
    add_index :jrc_crm_deals, :organization_id
    add_index :jrc_crm_deals, :company_id
    add_index :jrc_crm_deals, :status
    add_index :jrc_crm_deals, :expected_close_at
    add_index :jrc_crm_deals, :lead_id
  end
end
