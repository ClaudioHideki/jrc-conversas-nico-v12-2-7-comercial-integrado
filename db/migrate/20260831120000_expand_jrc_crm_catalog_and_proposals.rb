class ExpandJrcCrmCatalogAndProposals < ActiveRecord::Migration[7.1]
  def change
    change_table :jrc_crm_products, bulk: true do |t|
      t.string :product_type, default: 'service', null: false
      t.string :subcategory
      t.jsonb :tags, default: [], null: false
      t.string :sales_unit, default: 'unidade', null: false
      t.string :billing_model, default: 'one_time', null: false
      t.bigint :cost_cents, default: 0, null: false
      t.bigint :setup_fee_cents, default: 0, null: false
      t.bigint :minimum_price_cents, default: 0, null: false
      t.decimal :tax_rate, precision: 6, scale: 2, default: 0, null: false
      t.decimal :commission_rate, precision: 6, scale: 2, default: 0, null: false
      t.decimal :included_quantity, precision: 14, scale: 2, default: 0, null: false
      t.string :included_unit
      t.bigint :overage_unit_price_cents, default: 0, null: false
      t.integer :minimum_quantity, default: 1, null: false
      t.boolean :allow_variable_quantity, default: true, null: false
      t.integer :activation_days, default: 0, null: false
      t.integer :validation_period_days, default: 0, null: false
      t.boolean :rollover_allowance, default: false, null: false
      t.integer :contract_term_months, default: 12, null: false
      t.decimal :maximum_discount_percent, precision: 6, scale: 2, default: 20, null: false
      t.decimal :discount_approval_percent, precision: 6, scale: 2, default: 10, null: false
      t.string :renewal_type, default: 'automatic', null: false
      t.string :adjustment_index, default: 'IPCA', null: false
      t.integer :adjustment_period_months, default: 12, null: false
      t.decimal :cancellation_penalty_percent, precision: 6, scale: 2, default: 0, null: false
      t.boolean :allow_standalone_sale, default: true, null: false
      t.boolean :requires_contract, default: false, null: false
      t.string :fiscal_service_code
      t.jsonb :available_for, default: [], null: false
      t.jsonb :integrations, default: [], null: false
      t.string :proposal_template_name
      t.string :contract_template_name
      t.text :sales_notes
      t.text :technical_requirements
      t.text :scope_included
      t.text :scope_excluded
    end

    add_index :jrc_crm_products, [:account_id, :product_type], name: 'idx_jrc_crm_products_account_type'
    add_index :jrc_crm_products, [:account_id, :billing_model], name: 'idx_jrc_crm_products_account_billing'
    add_index :jrc_crm_products, [:account_id, :sku], name: 'idx_jrc_crm_products_account_sku'

    change_table :jrc_crm_proposals, bulk: true do |t|
      t.string :proposal_number
      t.integer :version_number, default: 1, null: false
      t.string :issuer_company_name, default: 'Grupo JRC', null: false
      t.string :issuer_tax_id
      t.string :issuer_unit
      t.string :payment_method
      t.integer :billing_day
      t.integer :first_billing_days, default: 0, null: false
      t.boolean :taxes_included, default: true, null: false
      t.string :annual_adjustment_index, default: 'IPCA', null: false
      t.string :renewal_type, default: 'automatic', null: false
      t.decimal :cancellation_penalty_percent, precision: 6, scale: 2, default: 0, null: false
      t.string :approval_status, default: 'not_required', null: false
      t.string :commercial_approval_status, default: 'not_required', null: false
      t.string :financial_approval_status, default: 'not_required', null: false
      t.string :technical_approval_status, default: 'not_required', null: false
      t.integer :viewed_count, default: 0, null: false
      t.datetime :last_viewed_at
      t.string :accepted_by_name
      t.string :accepted_by_document
      t.string :accepted_from_ip
      t.string :accepted_user_agent
      t.datetime :locked_at
      t.boolean :follow_up_enabled, default: true, null: false
      t.integer :follow_up_days, default: 3, null: false
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE jrc_crm_proposals
          SET proposal_number = 'PROP-' || LPAD(id::text, 6, '0'),
              commercial_approval_status = 'not_required',
              financial_approval_status = 'not_required',
              technical_approval_status = 'not_required'
          WHERE proposal_number IS NULL
        SQL
        change_column_null :jrc_crm_proposals, :proposal_number, false
      end
    end

    add_index :jrc_crm_proposals, [:account_id, :proposal_number], unique: true,
                                                                      name: 'idx_jrc_crm_proposals_account_number'

    change_table :jrc_crm_proposal_items, bulk: true do |t|
      t.string :billing_model, default: 'one_time', null: false
      t.string :unit_name, default: 'unidade', null: false
      t.bigint :setup_fee_cents, default: 0, null: false
      t.bigint :recurring_total_cents, default: 0, null: false
      t.bigint :initial_total_cents, default: 0, null: false
      t.decimal :included_quantity, precision: 14, scale: 2, default: 0, null: false
      t.string :included_unit
      t.bigint :overage_unit_price_cents, default: 0, null: false
      t.integer :activation_days, default: 0, null: false
      t.integer :validation_period_days, default: 0, null: false
    end
  end
end
