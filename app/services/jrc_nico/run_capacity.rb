class JrcNico::RunCapacity
  class Exceeded < StandardError; end

  # Call while holding the account lock, in the transaction that creates the run.
  def self.reservation_for!(account, conversation: nil, reservation_tokens: 270_000)
    month = JrcNico::Run.where(account: account, created_at: Time.current.all_month)
    limit = account.custom_attributes.fetch('nico_monthly_run_limit', 1000).to_i
    reservation = ENV['NICO_MODE'] == 'provider' ? reservation_tokens.clamp(1, 270_000) : 0
    token_limit = account.custom_attributes.fetch('nico_monthly_token_limit', 1_000_000).to_i
    operations = JrcNico::Inference.where(account: account, created_at: Time.current.all_month)
    tokens = account.jrc_ai_usage_events.current_month.where(agent_key: JrcNico::AgentCatalog::KEYS).sum(:total_tokens) +
             month.sum(:reserved_tokens) + operations.sum(:reserved_tokens)
    active = JrcNico::Run.where(account: account).active
    concurrency = account.custom_attributes.fetch('nico_concurrency', 3).to_i.clamp(1, 8)
    running = operations.where(status: 'running').where('created_at > ?', 2.minutes.ago).count
    raise Exceeded if month.count + operations.count >= limit || active.count + running >= concurrency || tokens + reservation > token_limit
    raise Exceeded if conversation && active.where(conversation: conversation).exists?

    reservation
  end
end
