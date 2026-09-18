class JrcFlows::Access
  def self.enabled?(account)
    ENV['JRC_FLOWS_ENABLED'] == 'true' && account&.active? && account.feature_enabled?('jrc_flows')
  end

  def self.external_beta?
    ENV['JRC_FLOWS_ENABLED'] == 'true' && ENV['JRC_FLOWS_EXTERNAL_BETA'] == 'true'
  end

  def self.inbox_bot_owned?(conversation)
    AgentBotInbox.active.exists?(account_id: conversation.account_id, inbox_id: conversation.inbox_id)
  end
end
