class AddJrcCrmIntegrityConstraints < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :jrc_crm_pipelines, :accounts
    add_foreign_key :jrc_crm_stages, :accounts
    add_foreign_key :jrc_crm_stages, :jrc_crm_pipelines, column: :pipeline_id
    add_foreign_key :jrc_crm_lost_reasons, :accounts
    add_foreign_key :jrc_crm_leads, :accounts
    add_foreign_key :jrc_crm_leads, :users, column: :owner_id
    add_foreign_key :jrc_crm_leads, :contacts
    add_foreign_key :jrc_crm_leads, :conversations
    add_foreign_key :jrc_crm_leads, :teams
    add_foreign_key :jrc_crm_deals, :accounts
    add_foreign_key :jrc_crm_deals, :jrc_crm_pipelines, column: :pipeline_id
    add_foreign_key :jrc_crm_deals, :jrc_crm_stages, column: :stage_id
    add_foreign_key :jrc_crm_deals, :users, column: :owner_id
    add_foreign_key :jrc_crm_deals, :contacts
    add_foreign_key :jrc_crm_deals, :teams
    add_foreign_key :jrc_crm_deals, :jrc_crm_lost_reasons, column: :lost_reason_id
    add_foreign_key :jrc_crm_deals, :jrc_crm_leads, column: :lead_id
    add_foreign_key :jrc_crm_deals, :jrc_crm_organizations, column: :organization_id
    add_foreign_key :jrc_crm_deal_contacts, :jrc_crm_deals, column: :deal_id
    add_foreign_key :jrc_crm_deal_contacts, :contacts
    add_foreign_key :jrc_crm_products, :accounts
    add_foreign_key :jrc_crm_deal_products, :jrc_crm_deals, column: :deal_id
    add_foreign_key :jrc_crm_deal_products, :jrc_crm_products, column: :product_id
    add_foreign_key :jrc_crm_proposals, :accounts
    add_foreign_key :jrc_crm_proposals, :jrc_crm_deals, column: :deal_id
    add_foreign_key :jrc_crm_proposals, :users, column: :owner_id
    add_foreign_key :jrc_crm_proposal_items, :jrc_crm_proposals, column: :proposal_id
    add_foreign_key :jrc_crm_proposal_items, :jrc_crm_products, column: :product_id
    add_foreign_key :jrc_crm_proposal_events, :accounts
    add_foreign_key :jrc_crm_proposal_events, :jrc_crm_proposals, column: :proposal_id
    add_foreign_key :jrc_crm_proposal_events, :users
    add_foreign_key :jrc_crm_activities, :accounts
    add_foreign_key :jrc_crm_activities, :jrc_crm_deals, column: :deal_id
    add_foreign_key :jrc_crm_activities, :jrc_crm_leads, column: :lead_id
    add_foreign_key :jrc_crm_activities, :contacts
    add_foreign_key :jrc_crm_activities, :conversations
    add_foreign_key :jrc_crm_activities, :users
    add_foreign_key :jrc_crm_activities, :jrc_crm_organizations, column: :organization_id
    add_foreign_key :jrc_crm_follow_ups, :accounts
    add_foreign_key :jrc_crm_follow_ups, :jrc_crm_deals, column: :deal_id
    add_foreign_key :jrc_crm_follow_ups, :jrc_crm_leads, column: :lead_id
    add_foreign_key :jrc_crm_follow_ups, :users
    add_foreign_key :jrc_crm_audit_events, :accounts
    add_foreign_key :jrc_crm_organizations, :accounts
    add_foreign_key :jrc_crm_organizations, :users, column: :owner_id
    add_foreign_key :jrc_crm_deal_conversations, :accounts
    add_foreign_key :jrc_crm_deal_conversations, :jrc_crm_deals, column: :deal_id
    add_foreign_key :jrc_crm_deal_conversations, :conversations
    add_foreign_key :jrc_crm_deal_conversations, :users, column: :created_by_id
  end
end
