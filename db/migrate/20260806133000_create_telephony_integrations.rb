class CreateTelephonyIntegrations < ActiveRecord::Migration[7.1]
  def change
    create_table :telephony_integrations do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :provider, null: false, default: 'hodupbx'
      t.boolean :history_enabled, null: false, default: false
      t.string :cdr_base_url, null: false, default: 'https://portal-cloud.jrcpabx.com.br'
      t.string :cdr_api_version, null: false, default: 'v1.4'
      t.text :cdr_token
      t.string :tenant_type, null: false, default: 'TENANT'
      t.integer :default_period_days, null: false, default: 7

      t.timestamps
    end
  end
end
