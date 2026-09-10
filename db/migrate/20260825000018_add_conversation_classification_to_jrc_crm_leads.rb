class AddConversationClassificationToJrcCrmLeads < ActiveRecord::Migration[7.0]
  def change
    add_column :jrc_crm_leads, :idempotency_key, :string
    add_column :jrc_crm_leads, :classified_at, :datetime

    add_index :jrc_crm_leads, [:account_id, :idempotency_key],
              unique: true,
              where: 'idempotency_key IS NOT NULL',
              name: 'idx_jrc_crm_leads_account_idempotency'
  end
end
