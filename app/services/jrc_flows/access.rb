class JrcFlows::Access
  def self.enabled?(account)
    ENV['JRC_FLOWS_ENABLED'] == 'true' && account&.active? && account.feature_enabled?('jrc_flows')
  end

  def self.external_beta?
    ENV['JRC_FLOWS_ENABLED'] == 'true' && ENV['JRC_FLOWS_EXTERNAL_BETA'] == 'true'
  end
end
