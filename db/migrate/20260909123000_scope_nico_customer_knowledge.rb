class ScopeNicoCustomerKnowledge < ActiveRecord::Migration[7.1]
  def change
    add_column :jrc_nico_knowledge_documents, :customer_visible, :boolean, null: false, default: false
  end
end
