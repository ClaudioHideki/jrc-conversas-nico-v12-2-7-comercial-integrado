class CreateWhatsappCallingConfigurations < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_calling_configurations do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.boolean :enabled, null: false, default: false
      t.string :waba_id
      t.string :phone_number_id
      t.text :access_token
      t.string :configuration_status, null: false, default: 'not_configured'

      t.timestamps
    end
  end
end
