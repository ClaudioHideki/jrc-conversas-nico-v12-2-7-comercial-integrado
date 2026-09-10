class JrcNico::NoticePlanJob < ApplicationJob
  queue_as :default

  def perform(notice_id)
    notice = JrcNico::Notice.find_by(id: notice_id)
    return unless notice&.kind == 'action'
    operator = JrcNico::OperatorSession.new(account: notice.account, user: notice.user)
    raise Pundit::NotAuthorizedError unless notice.visible_to?(operator.access)
    command = notice.with_lock do
      next unless %w[new planning succeeded].include?(notice.status)
      next if notice.commands.where(status: %w[planning awaiting_confirmation browser_pending executing unknown]).exists?
      if notice.commands.count >= 12
        notice.update!(status: 'review', body: 'O pedido atingiu doze etapas. Revise os resultados antes de continuar.', read_at: nil)
        next
      end
      notice.update!(status: 'planning')
      operator.session.commands.create!(source_notice: notice, request_id: SecureRandom.uuid, message: notice.request)
    end
    if command
      operator.plan_customer_request(command, notice)
      delegation = JrcNico::DelegatedActions.for_notice(notice)
      if command.status == 'awaiting_confirmation' && JrcNico::DelegatedActions.permitted?(delegation, command, operator.access)
        operator.execute(command, delegation: delegation)
      end
    end
  rescue StandardError => error
    detail = 'Não foi possível preparar a ação. Revise os dados e as permissões no módulo.'
    if command&.reload&.status == 'failed' && command.reply.present?
      detail = command.reply
    else
      command&.update!(status: 'failed', reply: detail)
    end
    notice&.update!(status: 'failed', body: detail, read_at: nil)
    Rails.logger.warn("NICO notice planning failed notice_id=#{notice_id} type=#{error.class.name}")
  end
end
