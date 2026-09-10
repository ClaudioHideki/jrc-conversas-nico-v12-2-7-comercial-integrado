class AddConversionKeyToJrcCrmDeals < ActiveRecord::Migration[7.1]
  def change
    add_column :jrc_crm_deals, :conversion_key, :string
    add_index :jrc_crm_deals, [:account_id, :conversion_key], unique: true,
                                                                where: 'conversion_key IS NOT NULL',
                                                                name: 'idx_jrc_crm_deals_account_conversion'
  end
end
