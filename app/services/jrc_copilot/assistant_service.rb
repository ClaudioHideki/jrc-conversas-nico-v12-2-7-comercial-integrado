class JrcCopilot::AssistantService < Captain::BaseTaskService
  pattr_initialize [
    :account!,
    :user!,
    :message!,
    { route_name: nil, route_path: nil, page_context: {}, history: [] }
  ]

  def perform
    fallback = JrcCopilot::TaskCatalog.fallback_answer(
      message: message,
      route_name: route_name
    )

    return ai_not_configured(fallback) unless configured_providers.any?
    return provider_adapter_unavailable(fallback) unless ai_provider

    response = make_api_call(
      model: configured_model,
      messages: llm_messages
    )

    return fallback.merge(ai_available: false, reason: response[:error]) if response[:error].present?

    record_usage(response)

    fallback.merge(
      message: response[:message],
      mode: 'ai',
      ai_available: true
    )
  rescue StandardError => e
    Rails.logger.warn("[jrc-copilot] #{e.class}: #{e.message}")
    JrcCopilot::TaskCatalog.fallback_answer(
      message: message,
      route_name: route_name
    ).merge(ai_available: false, reason: e.message)
  end

  private

  def llm_messages
    [{ role: 'system', content: system_prompt }] + sanitized_history + [
      { role: 'user', content: message.to_s.first(4_000) }
    ]
  end

  def sanitized_history
    Array(history).last(8).filter_map do |entry|
      role = entry[:role].to_s
      content = entry[:content].to_s.strip.first(2_000)
      next unless %w[user assistant].include?(role) && content.present?

      { role: role, content: content }
    end
  end

  def system_prompt
    <<~PROMPT
      Você é o Copiloto JRC, a inteligência operacional do JRC Conversas.
      Responda sempre em português do Brasil, de forma objetiva, segura e orientada à próxima ação.
      Sua função é guiar usuários nas tarefas de Atendimento, Conversas, E-mails, Chamadas, Contatos, CRM, Campanhas, Ramal, WhatsApp Calling e Videoconferência.

      Regras obrigatórias:
      - Oriente passo a passo e priorize uma ação por vez.
      - Nunca invente que uma integração, envio, chamada, sincronização ou automação funcionou.
      - Quando depender de credencial, permissão, configuração da Meta, conta de e-mail, Google, Outlook, PABX ou outro serviço, diga claramente que a configuração precisa ser validada.
      - Não sugira conectores externos de gestão que não façam parte do escopo aprovado desta versão.
      - Preserve o histórico omnichannel e recomende vincular atendimento, contato, lead, negócio, atividade e proposta quando fizer sentido.
      - Em propostas, os valores devem vir dos itens: implantação, recorrência, descontos e total inicial.
      - Atividades é a fila operacional; Agenda é a visão temporal do mesmo compromisso.
      - Não execute ações destrutivas. Oriente o usuário a revisar dados antes de excluir, cancelar ou marcar como perdido.
      - Quando não houver informação suficiente, faça uma pergunta curta e específica.
      - Agentes especialistas disponiveis: Prioridades, Atendimento, Qualidade, Retorno, Comercial, Agenda, SLA e Supervisor. Consulte mentalmente o especialista adequado e explique qual agente fundamentou a recomendacao.

      #{JrcCopilot::TaskCatalog.system_context(route_name)}
      Caminho atual: #{route_path.presence || 'não informado'}.
      Contexto adicional permitido pela interface: #{page_context.to_h.slice('entity_type', 'entity_id', 'title', 'status').to_json}.
      Usuário atual: #{user.name.presence || user.email}.
    PROMPT
  end


  def configured_model
    ai_provider.default_model
  end

  def configured_providers
    @configured_providers ||= account.jrc_ai_providers.enabled.preferred_first.select(&:api_key_configured?)
  rescue StandardError
    []
  end

  def ai_provider
    @ai_provider ||= configured_providers.find(&:openai_compatible?)
  end

  def llm_credential
    return unless ai_provider

    { api_key: ai_provider.api_key, source: :jrc_ai_provider }
  end

  def api_base
    ai_provider.request_base_url
  end

  def system_api_key
    nil
  end

  def ai_not_configured(fallback)
    fallback.merge(
      message: 'A Inteligência Artificial ainda não foi configurada pelo administrador desta conta. Cockpit, Conversas, CRM, Agenda, Ligações e WhatsApp Calling continuam funcionando normalmente.',
      mode: 'configuration_required',
      ai_available: false,
      reason: 'account_ai_not_configured'
    )
  end

  def provider_adapter_unavailable(fallback)
    fallback.merge(
      message: 'A conta possui um provedor de IA configurado, mas o adaptador desse provedor ainda não está habilitado nesta versão. Nenhuma credencial global será utilizada como alternativa.',
      mode: 'provider_unavailable',
      ai_available: false,
      reason: 'provider_adapter_unavailable'
    )
  end

  def record_usage(response)
    usage = response[:usage] || {}
    input_tokens = usage['prompt_tokens'].to_i
    output_tokens = usage['completion_tokens'].to_i

    account.jrc_ai_usage_events.create!(
      provider: ai_provider,
      user: user,
      agent_key: 'copilot',
      feature: event_name,
      model: configured_model,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      total_tokens: usage['total_tokens'].to_i,
      metadata: { route_name: route_name, route_path: route_path }.compact
    )
  rescue StandardError => e
    Rails.logger.warn("[jrc-copilot-usage] #{e.class}: #{e.message}")
  end

  def event_name
    'jrc_copilot'
  end

  # O Copiloto JRC usa credencial própria/da conta e não consome a cota do Captain.
  def counts_toward_usage?
    false
  end

  def use_account_openai_hook?
    false
  end

  # A verificação de disponibilidade é feita pela configuração da própria conta.
  # Mantemos este retorno para que o wrapper do Captain não imponha feature flag
  # ou credencial global antes da validação multiempresa acima.
  def captain_tasks_enabled?
    true
  end
end
