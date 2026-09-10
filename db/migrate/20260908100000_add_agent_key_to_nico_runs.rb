class AddAgentKeyToNicoRuns < ActiveRecord::Migration[7.1]
  def change
    add_column :jrc_nico_runs, :agent_key, :string, default: 'nico', null: false
    add_index :jrc_nico_runs, [:account_id, :agent_key, :created_at], name: 'nico_agent_history'
  end
end
