class JrcNico::WorkflowSummary
  def self.for(session)
    workflow_id = session.context['active_workflow_id']
    return unless workflow_id

    commands = session.commands.where("execution_context ->> 'workflow_id' = ?", workflow_id).order(:id).to_a
    writes = commands.select { |command| JrcNico::ToolCatalog::TOOLS.dig(command.tool, 2) == true }
    completed = writes.select { |command| command.status == 'succeeded' }
    uncertain = commands.any? { |command| %w[failed unknown cancelled].include?(command.status) }
    pending = commands.any? { |command| %w[planning executing awaiting_confirmation browser_pending].include?(command.status) }
    state = if uncertain
              completed.any? ? 'partial' : 'failed'
            elsif pending
              'pending'
            elsif completed.any?
              'recorded'
            else
              'answered'
            end
    # This is a ledger of completed steps, not a model-generated claim that the objective is fulfilled.
    { id: workflow_id, state: state, completed_count: completed.size,
      steps: writes.map { |command| { id: command.id, tool: command.tool, status: command.status, reply: command.reply } } }
  end
end
