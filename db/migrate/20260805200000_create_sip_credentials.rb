class CreateSipCredentials < ActiveRecord::Migration[7.1]
  def change
    create_table :sip_credentials do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :wss_server, null: false
      t.string :sip_domain, null: false
      t.string :extension, null: false
      t.string :username, null: false
      t.text :password, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    add_index :sip_credentials, [:account_id, :user_id], unique: true
  end
end
