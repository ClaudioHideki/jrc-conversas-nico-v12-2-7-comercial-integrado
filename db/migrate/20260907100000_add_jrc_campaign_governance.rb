class AddJrcCampaignGovernance < ActiveRecord::Migration[7.1]
  def change
    add_column :jrc_campaigns, :review_snapshot, :jsonb
    add_column :jrc_campaigns, :review_digest, :string
    add_column :jrc_campaigns, :approved_digest, :string
    add_column :jrc_campaigns, :approved_at, :datetime
    add_column :jrc_campaigns, :approval_expires_at, :datetime
    add_reference :jrc_campaigns, :approved_by, foreign_key: { to_table: :users }

    create_table :jrc_campaign_consents do |t|
      t.references :account, null: false, foreign_key: true
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.string :phone_number, null: false
      t.text :evidence, null: false
      t.datetime :granted_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :jrc_campaign_consents, [:account_id, :phone_number], unique: true,
                                                                    where: 'revoked_at IS NULL', name: 'index_jrc_campaign_consents_active_phone'
  end
end
