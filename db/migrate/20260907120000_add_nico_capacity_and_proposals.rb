class AddNicoCapacityAndProposals < ActiveRecord::Migration[7.1]
  def change
    add_column :jrc_nico_runs, :reserved_tokens, :integer, default: 0, null: false
    add_check_constraint :jrc_nico_runs, 'reserved_tokens >= 0', name: 'nico_nonnegative_reservation'
    create_table :jrc_nico_proposals do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :run, null: false, foreign_key: { to_table: :jrc_nico_runs, on_delete: :cascade }
      t.references :activity, foreign_key: { to_table: :jrc_crm_activities, on_delete: :nullify }
      t.uuid :request_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :digest, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :expires_at, null: false
      t.datetime :approved_at
      t.timestamps
    end
    add_index :jrc_nico_proposals, [:account_id, :user_id, :request_id], unique: true, name: 'nico_proposal_idempotency'
    add_check_constraint :jrc_nico_proposals, "status IN ('pending', 'executed')", name: 'nico_proposal_status'
  end
end
