class JrcNico::ResultAccess
  def self.allowed?(run)
    return true unless run.status == 'completed'
    return false unless run.source_manifest.is_a?(Array)

    access = JrcNico::Access.new(account: run.account, user: run.user, conversation: run.conversation).authorize!
    run.source_manifest.all? do |item|
      kind, id, digest = item.fetch('reference').split(':')
      case [item['source'], kind]
      when ['conversation', 'message']
        run.conversation.messages.where(account_id: run.account_id, private: false).exists?(id: id)
      when ['crm', 'lead']
        access.leads.exists?(id: id)
      when ['crm', 'deal']
        access.deals.exists?(id: id)
      when ['knowledge', 'document']
        document = JrcNico::KnowledgeDocument.where(account_id: run.account_id).approved.find_by(id: id)
        document && document.digest.first(12) == digest
      when ['erp', 'binding']
        binding = JrcNico::ErpBinding.find_by(id: id, account_id: run.account_id)
        binding && binding.version == digest && JrcNico::ErpContext.allowed?(account: run.account, user: run.user, conversation: run.conversation, binding: binding)
      else
        false
      end
    end
  rescue Pundit::NotAuthorizedError, KeyError
    false
  end
end
