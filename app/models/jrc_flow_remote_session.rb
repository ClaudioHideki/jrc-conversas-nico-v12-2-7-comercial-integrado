class JrcFlowRemoteSession < ApplicationRecord
  belongs_to :connection, class_name: 'JrcFlowConnection'
  belongs_to :flow, class_name: 'JrcFlow'
  validates :status, inclusion: { in: %w[ready running waiting delayed completed paused failed] }

  def snapshot
    as_json(only: %i[id status node_id trace error steps created_at finished_at wake_at conversation_id inbox_id]).merge(
      'contact_name' => variables['contact.name'], 'remote' => true,
      'conversation_url' => "#{connection.base_url}/app/accounts/#{connection.remote_account_id}/conversations/#{conversation_id}"
    )
  end
end
