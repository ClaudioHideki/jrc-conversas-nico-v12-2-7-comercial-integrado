class CreateJrcNicoFoundation < ActiveRecord::Migration[7.1]
  def change
    create_table :jrc_nico_runs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.uuid :request_id, null: false
      t.string :status, null: false, default: 'queued'
      t.text :message, null: false
      t.string :fingerprint, null: false
      t.jsonb :result, null: false, default: {}
      t.string :error_code
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :jrc_nico_runs, [:account_id, :user_id, :request_id], unique: true, name: 'idx_nico_run_request'
    add_index :jrc_nico_runs, [:account_id, :created_at]
    add_check_constraint :jrc_nico_runs, "status IN ('queued','running','completed','failed','cancelled')", name: 'nico_run_status'

    create_table :jrc_nico_knowledge_documents do |t|
      t.references :account, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :approved_by, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :approved_at
      t.timestamps
    end
    add_index :jrc_nico_knowledge_documents, [:account_id, :approved_at], name: 'idx_nico_approved_knowledge'
  end
end
