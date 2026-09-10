class AddNicoCommercialDelegation < ActiveRecord::Migration[7.1]
  def change
    add_column :jrc_nico_delegations, :allowed_actions, :jsonb, null: false, default: []
    add_column :jrc_nico_commands, :execution_context, :jsonb, null: false, default: {}
  end
end
