class JrcNico::ContinueCommandJob < ApplicationJob
  queue_as :default

  def perform(command_id)
    command = JrcNico::Command.find_by(id: command_id)
    return unless command&.status == 'succeeded' && command.source_notice_id.nil?

    operator = JrcNico::OperatorSession.new(account: command.session.account, user: command.session.user)
    operator.continue_workflow(command)
  rescue StandardError => error
    Rails.logger.warn("NICO continuation failed command_id=#{command_id} type=#{error.class.name}")
  end
end
