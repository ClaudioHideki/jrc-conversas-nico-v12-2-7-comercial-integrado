class ProtectNicoHistoryLifecycle < ActiveRecord::Migration[7.1]
  def change
    add_column :jrc_nico_runs, :source_manifest, :jsonb
    { account_id: :accounts, user_id: :users, conversation_id: :conversations }.each do |column, target|
      remove_foreign_key :jrc_nico_runs, target, column: column
      add_foreign_key :jrc_nico_runs, target, column: column, on_delete: :cascade
    end
    { account_id: :accounts, author_id: :users, approved_by_id: :users }.each do |column, target|
      remove_foreign_key :jrc_nico_knowledge_documents, target, column: column
      add_foreign_key :jrc_nico_knowledge_documents, target, column: column, on_delete: :cascade
    end
  end
end
