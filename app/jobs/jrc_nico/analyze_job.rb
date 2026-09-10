class JrcNico::AnalyzeJob < ApplicationJob
  queue_as :default

  def perform(run_id)
    run = JrcNico::Run.find_by(id: run_id)
    return unless run

    claimed = run.with_lock do
      next false unless run.status == 'queued'

      run.update!(status: 'running', started_at: Time.current)
      true
    end
    return unless claimed

    raise Pundit::NotAuthorizedError unless JrcNico::AgentCatalog.for_account(run.account).any? { |agent| agent[:key] == run.agent_key }

    context = JrcNico::ContextBuilder.new(account: run.account, user: run.user, conversation: run.conversation).build(run.message, agent_key: run.agent_key)
    ready = run.with_lock do
      next false unless run.status == 'running'

      run.update!(source_manifest: context.values.flatten.map { |item| item.slice(:source, :reference) })
      true
    end
    return unless ready

    result = JrcNico::RuntimeClient.new.analyze(run, context)
    # Same lock/order as admission: usage, reservation and terminal state change atomically.
    run.account.with_lock do
      run.with_lock do
        record_usage(run, result)
        run.update!(reserved_tokens: 0)
        run.update!(status: 'completed', result: result, finished_at: Time.current) if run.status == 'running'
      end
    end
  rescue StandardError => e
    Rails.logger.warn("NICO analysis failed run_id=#{run_id} type=#{e.class.name}")
    run&.with_lock do
      run.update!(status: 'failed', error_code: 'analysis_unavailable', finished_at: Time.current) if run.status == 'running'
    end
  end

  private

  def record_usage(run, result)
    return unless result['mode'] == 'provider'

    JrcAi::UsageEvent.create!(account: run.account, user: run.user, agent_key: run.agent_key, feature: 'assisted_analysis', model: result['model'],
                             **result.fetch('usage').symbolize_keys, metadata: { run_id: run.id, cost_available: false })
  end
end
