class AddWorkflowEngineToJrcFlows < ActiveRecord::Migration[7.1]
  def change
    add_column :jrc_flows, :engine, :string, null: false, default: 'native'
    add_column :jrc_flows, :source_ciphertext, :text
    add_column :jrc_flows, :credential_ciphertext, :text
  end
end
