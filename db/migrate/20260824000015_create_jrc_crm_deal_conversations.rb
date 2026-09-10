class CreateJrcCrmDealConversations < ActiveRecord::Migration[7.0]
  def change
    create_table :jrc_crm_deal_conversations do |t|
      t.integer :account_id, null: false
      t.bigint :deal_id, null: false
      t.integer :conversation_id, null: false
      t.integer :created_by_id
      t.timestamps null: false
    end

    add_index :jrc_crm_deal_conversations, :account_id
    add_index :jrc_crm_deal_conversations, :deal_id
    add_index :jrc_crm_deal_conversations, :conversation_id
    add_index :jrc_crm_deal_conversations, [:deal_id, :conversation_id], unique: true, name: 'idx_jrc_crm_deal_conversations_uniq'
  end
end
