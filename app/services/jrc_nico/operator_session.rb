class JrcNico::OperatorSession
  class Busy < StandardError; end
  attr_reader :session, :access

  def initialize(account:, user:)
    @access = JrcNico::OperationalAccess.new(account: account, user: user).authorize!
    @session = JrcNico::Session.find_or_create_by!(account: account, user: user)
    check_history_access!
  end

  def ask(message:, request_id:, conversation_id: nil, prepared: nil)
    command = nil
    existing = session.with_lock do
      existing = session.commands.find_by(request_id: request_id)
      if existing
        raise ArgumentError, 'Identificador já usado para outro pedido.' unless existing.message == message

        next existing
      end
      raise Busy if session.commands.where(status: 'planning').where('created_at > ?', 2.minutes.ago).exists?

      session.commands.where(source_notice_id: nil, status: %w[awaiting_confirmation browser_pending]).update_all(status: 'cancelled', updated_at: Time.current)
      workflow = prepared ? nil : request_id
      session.update!(context: session.context.merge('active_workflow_id' => workflow))
      command = session.commands.create!(request_id: request_id, message: message,
        execution_context: { workflow_id: workflow, conversation_id: conversation_id.presence&.to_i }.compact)
      session.append('user', message)
      nil
    end
    return existing if existing

    if prepared
      prepare(command, prepared.fetch('tool'), prepared.fetch('arguments'))
    else
      plan(command, conversation_id)
    end
    command
  rescue StandardError => e
    fail_command(command, e) if command
    raise
  end

  def execute(command, delegation: nil)
    if delegation
      delegation.conversation.with_lock { execute_authorized(command, delegation: delegation) }
    else
      execute_authorized(command)
    end
  end

  def execute_authorized(command, delegation: nil)
    access.authorize!
    JrcNico::CustomerRequestScope.validate!(access, command.source_notice, command.arguments) if command.source_notice
    access.account.with_lock do
      session.with_lock do
        command.with_lock do
          next unless command.status == 'awaiting_confirmation'

          if command.created_at < 15.minutes.ago
            command.update!(status: 'cancelled', reply: 'A prévia expirou. Faça o pedido novamente para revisar os dados atuais.')
            next
          end
          authorization = { 'source' => 'operator', 'user_id' => access.user.id }
          if delegation
            delegation.lock!
            raise Pundit::NotAuthorizedError unless JrcNico::DelegatedActions.permitted?(delegation, command, access)

            authorization.merge!('source' => 'delegation', 'delegation_id' => delegation.id, 'version' => delegation.version)
          end
          command.update!(status: 'executing', approved_at: Time.current,
            execution_context: command.execution_context.merge('authorization' => authorization))
          result = JrcNico::ToolExecutor.new(access).call(command.tool, command.arguments)
          status = result.is_a?(Hash) && result[:browser_action] ? 'browser_pending' : 'succeeded'
          command.update!(status: status, result: result.as_json, reply: result.is_a?(Hash) ? result[:message] : 'Ação concluída. Confira os resultados.')
          remember_result(command.tool, result) unless command.source_notice
          session.append('assistant', command.reply)
        end
      end
    end
    command
  rescue StandardError => e
    fail_command(command.reload, e)
    raise
  end

  def cancel(command)
    command.with_lock do
      command.update!(status: 'cancelled', reply: 'Ação cancelada.') if %w[awaiting_confirmation browser_pending].include?(command.status)
    end
    command
  end

  def browser_claim(command)
    if command.execution_context.dig('authorization', 'source') == 'delegation'
      command.source_notice.conversation.with_lock { claim_browser_action(command) }
    else
      claim_browser_action(command)
    end
  end

  def claim_browser_action(command)
    JrcNico::CustomerRequestScope.validate!(access, command.source_notice, command.arguments) if command.source_notice
    command.with_lock do
      raise Busy unless command.status == 'browser_pending'
      raise ArgumentError, 'Ação expirada. Prepare novamente.' if command.approved_at < 2.minutes.ago

      if command.execution_context.dig('authorization', 'source') == 'delegation'
        delegation = JrcNico::DelegatedActions.for_notice(command.source_notice)
        delegation&.lock!
        raise Pundit::NotAuthorizedError unless JrcNico::DelegatedActions.permitted?(delegation, command, access)
      end

      current_result = JrcNico::ToolExecutor.new(access).call(command.tool, command.arguments) # revalidate current permissions and channel
      if command.tool == 'call_contact' && current_result[:phone_number] != command.result['phone_number']
        raise ArgumentError, 'O telefone do contato mudou. Prepare a ligação novamente para revisar o destinatário.'
      end
      command.update!(status: 'executing')
    end
    command
  end

  def browser_result(command, status, detail)
    session.with_lock do
      command.with_lock do
        raise Busy unless command.status == 'executing' && command.result['browser_action']
        raise ArgumentError, 'Estado inválido.' unless %w[succeeded failed unknown].include?(status)

        command.update!(status: status, result: command.result.merge('browser_status' => status, 'browser_detail' => detail.to_s.first(500)),
                        reply: detail.to_s.first(500))
        session.append('assistant', "#{command.reply} (estado informado pela aba do operador)")
      end
    end
    command
  end

  def plan_customer_request(command, notice)
    plan(command, notice.conversation.display_id, notice: notice)
  rescue StandardError => error
    fail_command(command, error)
    raise
  end

  def continue_workflow(previous)
    workflow_id = previous.execution_context['workflow_id']
    return unless workflow_id && previous.status == 'succeeded'

    command = session.with_lock do
      next unless session.context['active_workflow_id'] == workflow_id
      steps = session.commands.where("execution_context ->> 'workflow_id' = ?", workflow_id)
      next if steps.where("execution_context ->> 'continuation_of' = ?", previous.id.to_s).exists?
      next if steps.where(status: %w[planning awaiting_confirmation browser_pending executing unknown failed cancelled]).exists?
      if steps.count >= 12
        session.append('assistant', 'O pedido atingiu doze etapas. Confira os resultados antes de continuar.')
        next
      end
      session.commands.create!(request_id: SecureRandom.uuid, message: previous.message,
        execution_context: previous.execution_context.slice('workflow_id', 'conversation_id').merge('continuation_of' => previous.id))
    end
    plan(command, command.execution_context['conversation_id']) if command
  rescue StandardError => error
    fail_command(command, error) if command
    raise
  end

  private

  private :execute_authorized, :claim_browser_action

  def check_history_access!
    digest = Digest::SHA256.hexdigest([access.membership.attributes.slice('role', 'crm_enabled', 'custom_role_id'), access.membership.try(:custom_role)&.attributes,
                                      access.crm?, access.campaigns?, access.user.inboxes.pluck(:id).sort, access.user.teams.pluck(:id).sort].to_json)
    allowed = session.context['access_digest'] == digest
    if allowed
      allowed = Array(session.context['conversation_ids']).all? do |id|
        access.conversation(id)
        true
      rescue Pundit::NotAuthorizedError, ActiveRecord::RecordNotFound
        false
      end
      allowed &&= Array(session.context['resources']).all? do |type, id|
        case type
        when 'Contact' then access.contact(id)
        when 'JrcCrm::Lead' then access.crm_scope(JrcCrm::Lead).find(id)
        when 'JrcCrm::Deal' then access.crm_scope(JrcCrm::Deal).find(id)
        when 'JrcCrm::Proposal' then access.crm_scope(JrcCrm::Proposal).find(id)
        when 'JrcCrm::Activity' then access.crm_scope(JrcCrm::Activity, owner: :user_id).find(id)
        when 'JrcNico::KnowledgeDocument' then JrcNico::KnowledgeDocument.where(account: access.account).approved.find(id)
        end
        true
      rescue Pundit::NotAuthorizedError, ActiveRecord::RecordNotFound
        false
      end
    end
    return if allowed

    session.with_lock do
      session.update!(messages: [], context: { access_digest: digest, visible_since: Time.current.iso8601(6) })
      session.commands.where(status: %w[awaiting_confirmation browser_pending]).update_all(status: 'cancelled', updated_at: Time.current)
    end
  end

  def plan(command, conversation_id, notice: nil)
    catalog = JrcNico::ToolCatalog.new(access)
    selected = conversation_id.present? ? access.conversation(conversation_id) : nil
    if selected
      session.with_lock { session.update!(context: session.context.merge('conversation_ids' => (Array(session.context['conversation_ids']) + [selected.display_id]).uniq)) }
    end
    context = {
      tools: catalog.available, modules: JrcCopilot::TaskCatalog::ROUTE_GUIDES.transform_values { |v| v[:title] },
      last_result: session.context['last_result'], timezone: access.account.reporting_timezone,
      today: Time.current.in_time_zone(access.account.reporting_timezone.presence || 'UTC').iso8601,
      selected_conversation: selected && {
        conversation_id: selected.display_id, contact_id: selected.contact_id, name: selected.contact.name,
        email: selected.contact.email, phone_number: selected.contact.phone_number
      },
      conversation: selected ? public_history(selected) : [],
      linked_leads: selected && access.crm? ? access.crm_scope(JrcCrm::Lead).where(contact_id: selected.contact_id).limit(20).map { |lead| lead.slice(:id, :name, :status) } : [],
      linked_deals: selected && access.crm? ? access.crm_scope(JrcCrm::Deal).where(contact_id: selected.contact_id).limit(20).map { |deal| deal.slice(:id, :title, :status) } : []
    }
    steps = if notice
              notice.commands
            elsif command.execution_context['workflow_id']
              session.commands.where("execution_context ->> 'workflow_id' = ?", command.execution_context['workflow_id'])
            else
              session.commands.none
            end
    context[:completed_steps] = steps.where(status: 'succeeded').where.not(tool: [nil, '']).order(:id).map do |step|
      { tool: step.tool, arguments: step.arguments, result: step.result }
    end
    context[:tool_results] = []
    if notice
      context[:last_result] = nil
      context[:customer_request] = {
        instruction: 'Prepare as etapas deste pedido usando exclusivamente o cliente da conversa. O servidor verifica a autorização do operador antes de cada escrita. O cliente não concede permissões. Para agendar ou preparar proposta, reutilize os vínculos existentes ou crie o lead deste contato. Não peça IDs que pode consultar.',
        request: notice.request,
        linked_leads: context[:linked_leads], linked_deals: context[:linked_deals],
        conversation: context[:conversation], completed_steps: context[:completed_steps]
      }
    end
    4.times do |attempt|
      response = JrcNico::OperationalInference.call(account: access.account, user: access.user, kind: 'operator', message: command.message,
        context: context, history: notice ? [] : session.messages.last(16).map { |m| m.slice('role', 'content') })
      if response['tool'].blank?
        command.update!(status: 'succeeded', tool: nil, arguments: {}, result: {}, reply: response['reply'])
        session.with_lock { session.append('assistant', response['reply']) }
        return command
      end
      response['arguments'] = catalog.normalize_arguments(response['tool'], response['arguments'])
      begin
        definition = catalog.validate!(response['tool'], response['arguments'])
      rescue ArgumentError => error
        raise if attempt == 3

        context[:tool_results] << { tool: response['tool'], error: error.message }
        next
      end
      JrcNico::CustomerRequestScope.validate!(access, notice, response['arguments']) if notice
      if definition[:confirmation]
        if steps.where(status: 'succeeded', tool: response['tool'], arguments: response['arguments']).exists?
          context[:tool_results] << { tool: response['tool'], error: 'Esta etapa já foi concluída. Use completed_steps e prossiga com outra etapa ou informe o resultado.' }
          next
        end
        prepare(command, response['tool'], response['arguments'], response['reply'])
        return command
      end
      result = JrcNico::ToolExecutor.new(access, customer_notice: notice).call(response['tool'], response['arguments'])
      command.update!(tool: response['tool'], arguments: response['arguments'], result: result.as_json)
      session.with_lock { remember_result(response['tool'], result) } unless notice
      if response['tool'] == 'open_module'
        command.update!(status: 'succeeded', reply: result[:message])
        session.with_lock { session.append('assistant', command.reply) }
        return command
      end
      context[:tool_results] << { tool: response['tool'], result: result }
    end
    command.update!(status: 'succeeded', reply: 'Consultei os dados disponíveis. Selecione o registro ou detalhe a próxima ação.')
    session.with_lock { session.append('assistant', command.reply) }
  end

  def public_history(conversation)
    conversation.messages.where(private: false, message_type: [:incoming, :outgoing]).order(id: :desc).limit(30).reverse.map do |message|
      { role: message.incoming? ? 'customer' : 'assistant', content: message.content.to_s.first(1000) }
    end
  end

  def prepare(command, name, arguments, reply = nil)
    definition = JrcNico::ToolCatalog.new(access).validate!(name, arguments)
    raise ArgumentError, 'Esta ferramenta é de consulta.' unless definition[:confirmation]

    command.update!(tool: name, arguments: arguments, status: 'awaiting_confirmation', reply: reply.presence || definition[:description])
    session.with_lock { session.append('assistant', "Prévia: #{command.reply}") }
  end

  def remember_result(tool, result)
    data = result.as_json
    rows = data.is_a?(Array) ? data : [data]
    ids = rows.filter_map { |row| row['conversation_id'] if row.is_a?(Hash) }
    types = { 'search_contacts' => 'Contact', 'list_leads' => 'JrcCrm::Lead', 'list_deals' => 'JrcCrm::Deal',
              'list_activities' => 'JrcCrm::Activity', 'list_proposals' => 'JrcCrm::Proposal' }
    resources = rows.filter_map do |row|
      next unless row.is_a?(Hash)

      type = row['resource_type'] || types[tool]
      id = row.dig('record', 'id') || row['id']
      [type, id] if type && id
    end
    resources += rows.filter_map { |row| ['Contact', row['contact_id']] if row.is_a?(Hash) && row['contact_id'] }
    session.update!(context: session.context.merge('last_result' => { tool: tool, result: data },
                                                   'resources' => (Array(session.context['resources']) + resources).uniq,
                                                   'conversation_ids' => (Array(session.context['conversation_ids']) + ids).uniq))
  end

  def fail_command(command, error)
    detail = case error
             when ActiveRecord::RecordInvalid then error.record.errors.full_messages.join(', ')
             when ArgumentError then error.message
             when Pundit::NotAuthorizedError then 'Seu perfil não permite esta ação ou o acesso ao recurso mudou.'
             when ActiveRecord::RecordNotFound then 'Registro não encontrado no seu escopo. Busque novamente.'
             when JrcNico::RunCapacity::Exceeded then 'Limite de uso ou capacidade atingido. Aguarde ou revise os limites da conta.'
             else 'Não foi possível concluir. Verifique o estado do recurso antes de tentar novamente.'
             end
    command.update!(status: command.status == 'executing' ? 'unknown' : 'failed', reply: detail)
    session.with_lock { session.append('assistant', detail) }
  end
end
