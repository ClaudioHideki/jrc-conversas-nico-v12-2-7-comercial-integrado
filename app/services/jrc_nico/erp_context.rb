class JrcNico::ErpContext
  def self.account_allowed?(account)
    ENV.fetch('ERP_ALLOWED_ACCOUNTS', '').split(',').include?(account.id.to_s)
  end

  def self.allowed?(account:, user:, conversation:, binding:)
    return false unless account_allowed?(account)

    setting = JrcNico::ErpSetting.find_by(account_id: account.id)
    membership = account.account_users.find_by(user_id: user.id)
    binding && binding.enabled? && binding.account_id == account.id && binding.contact_id == conversation.contact_id &&
      setting && setting.mode == binding.mode && membership&.administrator?
  end

  def self.build(account:, user:, conversation:, agent_key:)
    binding = JrcNico::ErpBinding.find_by(account_id: account.id, contact_id: conversation.contact_id)
    return [] unless allowed?(account: account, user: user, conversation: conversation, binding: binding)

    reference = "binding:#{binding.id}:#{binding.version}"
    result = JrcNico::ErpClient.new.call('context', { account_id: account.id, mode: binding.mode, agent_key: agent_key,
                                                   binding: binding.attributes.slice('cnpj', 'bemtevi_customer_id', 'helpdesk_company_id') })
    items = result.fetch('items')
    raise JrcNico::ErpClient::Error, 'invalid_context' unless result['mode'] == binding.mode && items.is_a?(Array) && items.length <= 10

    items.map do |item|
      raise JrcNico::ErpClient::Error, 'invalid_context' unless item.is_a?(Hash) && item['text'].is_a?(String) && item['text'].length <= 3500

      { source: 'erp', reference: reference, text: "Consulta #{Time.current.iso8601}; modo #{binding.mode}: #{item['text']}" }
    end
  rescue JrcNico::ErpClient::Error, KeyError
    [{ source: 'erp', reference: reference, text: 'ERP indisponível nesta consulta. Não afirmar consulta, saldo ou chamado atualizado. Solicitar verificação humana.' }]
  end
end
