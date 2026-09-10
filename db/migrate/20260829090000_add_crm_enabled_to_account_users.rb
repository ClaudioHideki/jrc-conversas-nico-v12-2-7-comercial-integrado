class AddCrmEnabledToAccountUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :account_users, :crm_enabled, :boolean, default: false, null: false
  end
end
