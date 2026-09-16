class JrcBroker::Context
  attr_reader :account, :user, :integration, :client

  def initialize(account:, user:)
    @account = account
    @user = user
    @integration = JrcBrokerIntegration.find_by!(account_id: account.id)
    token = JrcBroker::Configuration.credential_store.decrypt(account_id: account.id, ciphertext: integration.encrypted_control_key)
    @client = JrcBroker::Client.new(origin: integration.broker_origin, token: token, actor_id: user.id)
    remote = client.context
    JrcBroker::Configuration.validate_context!(remote, account.id, integration.organization_id)
    return if remote['destinationRevision'] == integration.destination_revision

    raise JrcBroker::Client::Error.new('JRC_BROKER_CONTEXT_CHANGED', status: 409)
  end

  def binding(inbox_id)
    inbox = account.inboxes.find(inbox_id)
    JrcBrokerInboxBinding.find_by!(account_id: account.id, inbox_id: inbox.id)
  end

  def bind_completed!(operation)
    return operation unless operation['state'] == 'SUCCEEDED'

    inbox = account.inboxes.find(operation.fetch('inboxId'))
    raise JrcBroker::Client::Error, 'JRC_BROKER_INVALID_RESPONSE' unless inbox.channel_type == 'Channel::Api'

    # Network verification precedes the local transaction and never creates an inbox.
    status = client.status(operation.fetch('integrationId'))
    unless status['integrationStatus'] == 'READY' &&
           status.values_at('integrationId', 'inboxId', 'instanceId') == operation.values_at('integrationId', 'inboxId', 'instanceId')
      raise JrcBroker::Client::Error, 'JRC_BROKER_INVALID_RESPONSE'
    end

    save_binding!(inbox, operation)
    operation
  end

  private

  def save_binding!(inbox, operation)
    inbox.with_lock do
      binding = JrcBrokerInboxBinding.find_or_initialize_by(account_id: account.id, inbox_id: inbox.id)
      if binding.persisted? && binding.integration_id != operation['integrationId']
        raise JrcBroker::Client::Error.new('JRC_BROKER_ALREADY_BOUND', status: 409)
      end

      binding.update!(integration_id: operation.fetch('integrationId'), instance_id: operation.fetch('instanceId'))
    end
  end
end
