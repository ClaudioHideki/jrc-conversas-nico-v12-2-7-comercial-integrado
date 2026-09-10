class AddCallHistoryExtensionToSipCredentials < ActiveRecord::Migration[7.1]
  def up
    add_column :sip_credentials, :call_history_extension, :string

    # Existing installations keep their current behavior until the Super Admin
    # explicitly sets the PBX history extension for each agent.
    execute <<~SQL.squish
      UPDATE sip_credentials
      SET call_history_extension = extension
      WHERE call_history_extension IS NULL
    SQL
  end

  def down
    remove_column :sip_credentials, :call_history_extension
  end
end
