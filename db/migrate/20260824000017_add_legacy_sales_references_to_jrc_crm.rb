class AddLegacySalesReferencesToJrcCrm < ActiveRecord::Migration[7.1]
  def change
    add_column :jrc_crm_pipelines, :legacy_sales_pipeline_id, :bigint
    add_column :jrc_crm_stages, :legacy_sales_stage_id, :bigint
    add_column :jrc_crm_lost_reasons, :legacy_sales_loss_reason_id, :bigint
    add_column :jrc_crm_deals, :legacy_sales_opportunity_id, :bigint
    add_column :jrc_crm_deals, :product_name, :string
    add_column :jrc_crm_deals, :temperature, :string, default: 'warm', null: false
    add_column :jrc_crm_activities, :legacy_sales_activity_id, :bigint
    add_column :jrc_crm_activities, :status, :string, default: 'scheduled', null: false
    add_column :jrc_crm_audit_events, :legacy_sales_stage_history_id, :bigint

    add_index :jrc_crm_pipelines, [:account_id, :legacy_sales_pipeline_id], unique: true,
              where: 'legacy_sales_pipeline_id IS NOT NULL', name: 'idx_jrc_crm_pipelines_legacy_sales'
    add_index :jrc_crm_stages, [:account_id, :legacy_sales_stage_id], unique: true,
              where: 'legacy_sales_stage_id IS NOT NULL', name: 'idx_jrc_crm_stages_legacy_sales'
    add_index :jrc_crm_lost_reasons, [:account_id, :legacy_sales_loss_reason_id], unique: true,
              where: 'legacy_sales_loss_reason_id IS NOT NULL', name: 'idx_jrc_crm_reasons_legacy_sales'
    add_index :jrc_crm_deals, [:account_id, :legacy_sales_opportunity_id], unique: true,
              where: 'legacy_sales_opportunity_id IS NOT NULL', name: 'idx_jrc_crm_deals_legacy_sales'
    add_index :jrc_crm_activities, [:account_id, :legacy_sales_activity_id], unique: true,
              where: 'legacy_sales_activity_id IS NOT NULL', name: 'idx_jrc_crm_activities_legacy_sales'
    add_index :jrc_crm_audit_events, [:account_id, :legacy_sales_stage_history_id], unique: true,
              where: 'legacy_sales_stage_history_id IS NOT NULL', name: 'idx_jrc_crm_audits_legacy_sales'
  end
end
