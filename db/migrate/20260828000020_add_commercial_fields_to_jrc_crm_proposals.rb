class AddCommercialFieldsToJrcCrmProposals < ActiveRecord::Migration[7.1]
  def change
    add_column :jrc_crm_proposals, :solution_description, :text
    add_column :jrc_crm_proposals, :implementation_cents, :bigint, default: 0, null: false
    add_column :jrc_crm_proposals, :monthly_cents, :bigint, default: 0, null: false
    add_column :jrc_crm_proposals, :valid_until, :date
    add_column :jrc_crm_proposals, :term_months, :integer, default: 12, null: false
    add_column :jrc_crm_proposals, :commercial_notes, :text
    add_column :jrc_crm_proposals, :next_steps, :text
    add_column :jrc_crm_proposals, :last_sent_channel, :string
    add_column :jrc_crm_proposals, :last_sent_message_id, :bigint
    add_column :jrc_crm_proposals, :last_sent_conversation_id, :integer

    add_index :jrc_crm_proposals, :last_sent_message_id
    add_index :jrc_crm_proposals, :last_sent_conversation_id
  end
end
