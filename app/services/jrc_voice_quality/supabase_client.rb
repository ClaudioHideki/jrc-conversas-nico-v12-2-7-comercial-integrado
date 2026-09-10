class JrcVoiceQuality::SupabaseClient
  REQUEST_TIMEOUT = 20

  # Compatibilidade temporaria com o Supabase antigo.
  # account_id foi removido da consulta porque a view atual
  # vw_qualidade_pabx_dashboard ainda nao possui essa coluna.
  SUMMARY_FIELDS = %w[
    analise_id
    chamada_id
    call_id
    arquivo_audio
    telefone_origem
    ramal
    agente
    data_chamada
    status_chamada
    texto_transcrito
    modelo_transcricao
    resumo_conversa
    sentimento_cliente
    sentimento_atendente
    temperatura_conversa
    risco_churn
    risco_reclamacao
    nota_final
    classificacao_ligacao
    status_monitoria
    alerta_supervisao
    motivo_alerta
    confianca_transcricao
    observacao_transcricao
    payload_completo
    analise_criada_em
  ].freeze

  def configured?
    supabase_url.present? && service_role_key.present?
  end

  def find_analyses_by_call_ids(account_id:, call_ids:)
    return {} if call_ids.blank? || !configured?

    rows = request(
      :get,
      '/vw_qualidade_pabx_dashboard',
      query: {
        select: SUMMARY_FIELDS.join(','),
        call_id: "in.(#{postgrest_list(call_ids)})",
        order: 'analise_criada_em.desc'
      }
    )

    Array(rows).each_with_object({}) do |row, memo|
      memo[row['call_id']] ||= summary_payload(row)
    end
  rescue JrcVoiceQuality::PersistenceError => e
    Rails.logger.warn("[JRC Voice Quality] Supabase indisponivel ao buscar analises: #{e.message}")
    {}
  end

  def find_analysis(account_id:, call_id:)
    return if call_id.blank?

    raise_configuration! unless configured?

    rows = request(
      :get,
      '/vw_qualidade_pabx_dashboard',
      query: {
        select: SUMMARY_FIELDS.join(','),
        call_id: "eq.#{call_id}",
        order: 'analise_criada_em.desc',
        limit: 1
      }
    )

    row = Array(rows).first
    row ? summary_payload(row) : nil
  end

  def upsert_call!(metadata)
  raise_configuration! unless configured?

  compatible_metadata = metadata.except(
    :account_id,
    'account_id',
    :user_id,
    'user_id',
    :conversation_id,
    'conversation_id',
    :inbox_id,
    'inbox_id',
    :direction,
    'direction',
    :telefone_destino,
    'telefone_destino',
    :recording_url,
    'recording_url'
  )

  call_id = compatible_metadata[:call_id] || compatible_metadata['call_id']

  # Compatibilidade temporaria com o Supabase antigo:
  # evita UPDATE porque o trigger antigo referencia NEW.atualizado_em.
  if call_id.present?
    existing_rows = request(
      :get,
      '/chamadas_pabx',
      query: {
        select: '*',
        call_id: "eq.#{call_id}",
        limit: 1
      }
    )

    existing_call = Array(existing_rows).first
    return existing_call if existing_call.present?
  end

  rows = request(
    :post,
    '/chamadas_pabx',
    body: compatible_metadata,
    headers: {
      'Prefer' => 'return=representation'
    }
  )

  Array(rows).first ||
    raise(
      JrcVoiceQuality::PersistenceError.new(
        'Supabase nao retornou a chamada registrada',
        code: :supabase_error
      )
    )
end

  def save_transcription!(account_id:, chamada_id:, text:, model:)
    request(
      :post,
      '/transcricoes_pabx',
      body: {
        chamada_id: chamada_id,
        texto_transcrito: text,
        modelo_transcricao: model
      },
      headers: {
        'Prefer' => 'return=minimal'
      }
    )
  end

  def save_analysis!(account_id:, chamada_id:, analysis:)
    av = analysis.fetch('avaliacao_atendente', {})

    request(
      :post,
      '/analises_qualidade_pabx',
      body: {
        chamada_id: chamada_id,
        resumo_conversa: analysis['resumo_conversa'],
        assuntos_abordados: array_value(analysis['assuntos_abordados']),
        sentimento_cliente: analysis['sentimento_cliente'],
        sentimento_atendente: analysis['sentimento_atendente'],
        temperatura_conversa: analysis['temperatura_conversa'],
        tom_cliente: analysis['tom_cliente'],
        tom_atendente: analysis['tom_atendente'],
        houve_agressividade_cliente: truthy?(analysis['houve_agressividade_cliente']),
        houve_agressividade_atendente: truthy?(analysis['houve_agressividade_atendente']),
        houve_empatia: truthy?(analysis['houve_empatia']),
        houve_cordialidade: truthy?(analysis['houve_cordialidade']),
        houve_interrupcao: truthy?(analysis['houve_interrupcao']),
        cliente_demonstrou_insatisfacao: truthy?(analysis['cliente_demonstrou_insatisfacao']),
        cliente_ameacou_cancelar: truthy?(analysis['cliente_ameacou_cancelar']),
        cliente_mencionou_procon_anatel: truthy?(analysis['cliente_mencionou_procon_anatel']),
        cliente_mencionou_processo: truthy?(analysis['cliente_mencionou_processo']),
        problema_resolvido: truthy?(analysis['problema_resolvido']),
        necessita_retorno: truthy?(analysis['necessita_retorno']),
        risco_churn: analysis['risco_churn'],
        risco_reclamacao: analysis['risco_reclamacao'],
        cordialidade: bounded_integer(av['cordialidade'], 0, 10),
        empatia: bounded_integer(av['empatia'], 0, 10),
        clareza_comunicacao: bounded_integer(av['clareza_comunicacao'], 0, 10),
        dominio_assunto: bounded_integer(av['dominio_assunto'], 0, 10),
        conducao_conversa: bounded_integer(av['conducao_conversa'], 0, 10),
        resolucao_problema: bounded_integer(av['resolucao_problema'], 0, 15),
        cumprimento_protocolo: bounded_integer(av['cumprimento_protocolo'], 0, 10),
        controle_emocional: bounded_integer(av['controle_emocional'], 0, 10),
        experiencia_cliente: bounded_integer(av['experiencia_cliente'], 0, 15),
        nota_final: bounded_integer(
          av['nota_final'] || analysis['nota_final'],
          0,
          100
        ),
        pontos_positivos: array_value(analysis['pontos_positivos']),
        pontos_negativos: array_value(analysis['pontos_negativos']),
        oportunidades_melhoria: array_value(analysis['oportunidades_melhoria']),
        treinamento_recomendado: array_value(analysis['treinamento_recomendado']),
        classificacao_ligacao: analysis['classificacao_ligacao'],
        status_monitoria: analysis['status_monitoria'],
        alerta_supervisao: truthy?(analysis['alerta_supervisao']),
        motivo_alerta: analysis['motivo_alerta'].to_s,
        confianca_transcricao: analysis['confianca_transcricao'],
        observacao_transcricao: analysis['observacao_transcricao'],
        payload_completo: analysis
      },
      headers: {
        'Prefer' => 'return=minimal'
      }
    )
  end

  def update_call_status!(chamada_id:, status:)
    request(
      :patch,
      '/chamadas_pabx',
      query: {
        id: "eq.#{chamada_id}"
      },
      body: {
        status: status
      },
      headers: {
        'Prefer' => 'return=minimal'
      }
    )
  rescue JrcVoiceQuality::PersistenceError => e
    Rails.logger.warn(
      "[JRC Voice Quality] Falha ao atualizar status no Supabase: #{e.message}"
    )
  end

  private

  def supabase_url
    ENV.fetch('SUPABASE_URL', '').to_s.delete_suffix('/')
  end

  def service_role_key
    ENV.fetch('SUPABASE_SERVICE_ROLE_KEY', '').to_s
  end

  def rest_url
    "#{supabase_url}/rest/v1"
  end

  def raise_configuration!
    raise JrcVoiceQuality::ConfigurationError.new(
      'Supabase nao configurado. Defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY.',
      code: :supabase_not_configured
    )
  end

  def request(method, path, query: {}, body: nil, headers: {})
    response = HTTParty.public_send(
      method,
      "#{rest_url}#{path}",
      query: query,
      body: body&.to_json,
      headers: default_headers.merge(headers),
      timeout: REQUEST_TIMEOUT
    )

    return parse_response(response) if response.success?

    raise JrcVoiceQuality::PersistenceError.new(
      "Supabase retornou HTTP #{response.code}: #{response.body}",
      code: :supabase_error
    )
  rescue HTTParty::Error,
         SocketError,
         Errno::ECONNREFUSED,
         Net::OpenTimeout,
         Net::ReadTimeout => e
    raise JrcVoiceQuality::PersistenceError.new(
      "Falha ao conectar no Supabase: #{e.message}",
      code: :supabase_error
    )
  end

  def parse_response(response)
    return [] if response.body.blank?

    JSON.parse(response.body)
  rescue JSON::ParserError
    raise JrcVoiceQuality::PersistenceError.new(
      'Supabase retornou JSON invalido',
      code: :supabase_error
    )
  end

  def default_headers
    {
      'apikey' => service_role_key,
      'Authorization' => "Bearer #{service_role_key}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',

      # Evita resposta gzip que esta versao do HTTParty
      # estava entregando sem descompactar.
      'Accept-Encoding' => 'identity'
    }
  end

  def postgrest_list(values)
    Array(values)
      .compact
      .uniq
      .map { |value| %("#{value.to_s.gsub('"', '\"')}") }
      .join(',')
  end

  def summary_payload(row)
    payload =
      row['payload_completo'].is_a?(Hash) ? row['payload_completo'] : {}

    {
      id: row['analise_id'],
      chamada_id: row['chamada_id'],
      call_id: row['call_id'],
      status: row['status_monitoria'],
      nota_final:
        row['nota_final'] ||
        payload.dig('avaliacao_atendente', 'nota_final') ||
        payload['nota_final'],
      classificacao_ligacao: row['classificacao_ligacao'],
      sentimento_cliente: row['sentimento_cliente'],
      sentimento_atendente: row['sentimento_atendente'],
      temperatura_conversa: row['temperatura_conversa'],
      risco_churn: row['risco_churn'],
      risco_reclamacao: row['risco_reclamacao'],
      resumo_conversa: row['resumo_conversa'],
      alerta_supervisao: row['alerta_supervisao'],
      motivo_alerta: row['motivo_alerta'],
      confianca_transcricao: row['confianca_transcricao'],
      observacao_transcricao: row['observacao_transcricao'],
      texto_transcrito: row['texto_transcrito'],
      payload_completo: payload,
      created_at: row['analise_criada_em']
    }
  end

  def array_value(value)
    return value if value.is_a?(Array)
    return [] if value.blank?

    [value]
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def bounded_integer(value, min, max)
    value.to_i.clamp(min, max)
  end
end