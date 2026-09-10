class CreateJrcCrmProposals < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_proposals do |t|
      t.integer :account_id, null: false
      t.bigint :deal_id, null: false
      t.integer :owner_id, null: false
      t.string :title, null: false
      t.string :status, default: 'draft', null: false
      t.bigint :subtotal_cents, default: 0, null: false
      t.bigint :discount_cents, default: 0, null: false
      t.bigint :total_cents, default: 0, null: false
      t.string :public_token_digest, null: false
      t.datetime :public_token_expires_at
      t.datetime :public_token_revoked_at
      t.text :notes
      t.text :customer_notes
      t.datetime :sent_at
      t.datetime :viewed_at
      t.datetime :accepted_at
      t.datetime :rejected_at
      t.datetime :canceled_at
      t.integer :lock_version, default: 0, null: false
      t.timestamps null: false
    end

    add_index :jrc_crm_proposals, :account_id
    add_index :jrc_crm_proposals, :deal_id
    add_index :jrc_crm_proposals, :public_token_digest, unique: true
    add_index :jrc_crm_proposals, :status

    create_table :jrc_crm_proposal_items do |t|
      t.bigint :proposal_id, null: false
      t.bigint :product_id
      t.string :name_snapshot, null: false
      t.text :description_snapshot
      t.integer :quantity, default: 1, null: false
      t.bigint :unit_price_cents, default: 0, null: false
      t.bigint :discount_cents, default: 0, null: false
      t.bigint :total_cents, default: 0, null: false
      t.text :notes
      t.timestamps null: false
    end

    add_index :jrc_crm_proposal_items, :proposal_id
    add_index :jrc_crm_proposal_items, :product_id

    create_table :jrc_crm_proposal_events do |t|
      t.integer :account_id, null: false
      t.bigint :proposal_id, null: false
      t.integer :user_id
      t.string :event_type, null: false
      t.text :description
      t.jsonb :metadata, default: {}
      t.datetime :created_at, null: false
    end

    add_index :jrc_crm_proposal_events, :account_id
    add_index :jrc_crm_proposal_events, :proposal_id
    add_index :jrc_crm_proposal_events, :event_type
  end
end
