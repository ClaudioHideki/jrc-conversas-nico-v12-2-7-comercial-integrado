class JrcVoiceQuality::LocalAnalyzer
  KEYWORDS = {
    critical: ['cancelar', 'cancelamento', 'anatel', 'procon', 'processo', 'advogado', 'justica', 'descaso', 'absurdo'],
    negative: ['problema', 'ruim', 'pessimo', 'horrivel', 'lento', 'sem internet', 'queda', 'instabilidade', 'nao funciona', 'demora', 'reclamacao', 'insatisfeito'],
    positive: ['obrigado', 'obrigada', 'resolvido', 'funcionou', 'bom atendimento', 'excelente', 'otimo', 'satisfeito', 'perfeito'],
    empathy: ['entendo', 'compreendo', 'sinto muito', 'vamos resolver', 'peco desculpas', 'desculpe', 'lamento'],
    cordiality: ['bom dia', 'boa tarde', 'boa noite', 'por favor', 'senhor', 'senhora', 'a disposicao', 'meu nome e', 'como posso'],
    resolution: ['resolvido', 'normalizado', 'solucionado', 'voltou a funcionar', 'funcionando'],
    follow_up: ['chamado', 'protocolo', 'retorno', 'equipe tecnica', 'visita', 'prazo'],
    interruption: ['me deixa falar', 'me escuta', 'calma', 'deixa eu terminar'],
    impatience: ['ja falei', 'nao posso fazer nada', 'nao e comigo', 'desliga e liga', 'cala a boca', 'problema seu']
  }.freeze

  def initialize(transcript)
    @transcript = transcript.to_s
    @normalized = I18n.transliterate(@transcript.downcase)
  end

  def call
    quality = transcription_quality
    flags = behavior_flags
    scores = scores_for(flags, quality)
    classification = classification_for(scores, flags)
    monitor_status = monitor_status_for(classification, flags)

    {
      'resumo_conversa' => summary,
      'assuntos_abordados' => subjects,
      'sentimento_cliente' => customer_sentiment(flags),
      'sentimento_atendente' => agent_sentiment(flags),
      'temperatura_conversa' => temperature(flags),
      'tom_cliente' => customer_tone(flags),
      'tom_atendente' => agent_tone(flags),
      'houve_agressividade_cliente' => flags[:customer_aggression],
      'houve_agressividade_atendente' => flags[:agent_aggression],
      'houve_empatia' => flags[:empathy],
      'houve_cordialidade' => flags[:cordiality],
      'houve_interrupcao' => flags[:interruption],
      'cliente_demonstrou_insatisfacao' => flags[:negative] || flags[:critical],
      'cliente_ameacou_cancelar' => flags[:cancel],
      'cliente_mencionou_procon_anatel' => flags[:regulatory],
      'cliente_mencionou_processo' => flags[:legal],
      'problema_resolvido' => flags[:resolved],
      'necessita_retorno' => flags[:follow_up] && !flags[:resolved],
      'risco_churn' => churn_risk(flags),
      'risco_reclamacao' => complaint_risk(flags),
      'avaliacao_atendente' => scores,
      'pontos_positivos' => positive_points(flags),
      'pontos_negativos' => negative_points(flags),
      'oportunidades_melhoria' => improvement_points(flags),
      'treinamento_recomendado' => training_points(flags),
      'classificacao_ligacao' => classification,
      'status_monitoria' => monitor_status,
      'alerta_supervisao' => supervision_alert?(scores, flags),
      'motivo_alerta' => alert_reason(scores, flags),
      'confianca_transcricao' => quality[:confidence],
      'observacao_transcricao' => quality[:note],
      'confianca_analise' => 'media',
      'texto_transcrito' => @transcript
    }
  end

  private

  def include_any?(key)
    KEYWORDS.fetch(key).any? { |word| @normalized.include?(word) }
  end

  def behavior_flags
    {
      critical: include_any?(:critical),
      negative: include_any?(:negative),
      positive: include_any?(:positive),
      empathy: include_any?(:empathy),
      cordiality: include_any?(:cordiality),
      resolved: include_any?(:resolution),
      follow_up: include_any?(:follow_up),
      interruption: include_any?(:interruption),
      impatience: include_any?(:impatience),
      cancel: @normalized.include?('cancelar') || @normalized.include?('cancelamento'),
      regulatory: @normalized.include?('anatel') || @normalized.include?('procon'),
      legal: @normalized.include?('processo') || @normalized.include?('processar') || @normalized.include?('advogado'),
      customer_aggression: (@normalized.include?('absurdo') || @normalized.include?('descaso')) && include_any?(:critical),
      agent_aggression: @normalized.include?('cala a boca') || @normalized.include?('problema seu')
    }
  end

  def transcription_quality
    stripped = @transcript.strip
    return { confidence: 'baixa', note: 'Transcricao vazia ou muito curta para avaliacao confiavel.' } if stripped.length < 20
    return { confidence: 'media', note: 'Transcricao curta. A analise automatica pode ter precisao limitada.' } if stripped.length < 100

    { confidence: 'alta', note: 'Transcricao com boa legibilidade.' }
  end

  def scores_for(flags, quality)
    scores = {
      'cordialidade' => flags[:agent_aggression] ? 1 : (flags[:cordiality] ? 9 : 6),
      'empatia' => flags[:agent_aggression] ? 1 : (flags[:empathy] ? 9 : 5),
      'clareza_comunicacao' => quality[:confidence] == 'baixa' ? 5 : 8,
      'dominio_assunto' => flags[:agent_aggression] ? 3 : 8,
      'conducao_conversa' => flags[:agent_aggression] ? 2 : (flags[:interruption] ? 6 : 8),
      'resolucao_problema' => flags[:resolved] ? 14 : (flags[:follow_up] ? 5 : 8),
      'cumprimento_protocolo' => flags[:cordiality] ? 9 : 6,
      'controle_emocional' => flags[:agent_aggression] ? 2 : (temperature(flags) == 'critica' ? 6 : 9),
      'experiencia_cliente' => customer_experience_score(flags)
    }
    scores['nota_final'] = scores.values.sum
    scores
  end

  def customer_experience_score(flags)
    return 14 if flags[:positive] && !flags[:negative]
    return 2 if flags[:critical]
    return 5 if flags[:negative]

    9
  end

  def classification_for(scores, flags)
    return 'critica' if temperature(flags) == 'critica' || flags[:agent_aggression] || flags[:customer_aggression]
    return 'excelente' if scores['nota_final'] >= 90
    return 'boa' if scores['nota_final'] >= 75
    return 'regular' if scores['nota_final'] >= 60
    return 'ruim' if scores['nota_final'] >= 40

    'critica'
  end

  def monitor_status_for(classification, flags)
    return 'critica_para_supervisao' if classification == 'critica' || churn_risk(flags) == 'critico' || complaint_risk(flags) == 'critico'
    return 'reprovada' if classification == 'ruim'
    return 'aprovada_com_observacao' if %w[boa regular].include?(classification)

    'aprovada'
  end

  def customer_sentiment(flags)
    return 'critico' if flags[:critical]
    return 'negativo' if flags[:negative]
    return 'positivo' if flags[:positive]

    'neutro'
  end

  def agent_sentiment(flags)
    return 'negativo' if flags[:agent_aggression] || flags[:impatience]
    return 'positivo' if flags[:empathy] || flags[:cordiality]

    'neutro'
  end

  def temperature(flags)
    return 'critica' if flags[:critical] || flags[:customer_aggression] || flags[:agent_aggression] || flags[:regulatory] || flags[:legal]
    return 'quente' if flags[:negative]
    return 'fria' if flags[:positive]

    'neutra'
  end

  def customer_tone(flags)
    return 'agressivo' if flags[:customer_aggression]
    return 'insatisfeito' if flags[:critical]
    return 'irritado' if flags[:negative]
    return 'cordial' if flags[:positive]

    'calmo'
  end

  def agent_tone(flags)
    return 'agressivo' if flags[:agent_aggression]
    return 'impaciente' if flags[:impatience]
    return 'empatico' if flags[:empathy]
    return 'cordial' if flags[:cordiality]

    'neutro'
  end

  def churn_risk(flags)
    return 'critico' if flags[:critical] && flags[:cancel]
    return 'alto' if flags[:critical]
    return 'medio' if flags[:negative]

    'baixo'
  end

  def complaint_risk(flags)
    return 'critico' if flags[:regulatory] || flags[:legal]
    return 'alto' if flags[:critical]
    return 'medio' if flags[:negative]

    'baixo'
  end

  def subjects
    found = []
    found << 'financeiro' if @normalized.match?(/boleto|pagamento|cobranca|fatura|mensalidade|vencimento/)
    found << 'suporte tecnico' if @normalized.match?(/internet|roteador|wifi|sinal|queda|lento|fibra/)
    found << 'cancelamento' if @normalized.include?('cancel')
    found << 'reclamacao' if @normalized.match?(/anatel|procon|processo|reclam/)
    found << 'comercial' if @normalized.match?(/plano|upgrade|contratar|contrato|comercial/)
    found.presence || ['outros']
  end

  def positive_points(flags)
    points = []
    points << 'Atendente utilizou linguagem cordial e respeitosa.' if flags[:cordiality]
    points << 'Atendente demonstrou empatia e atencao ao cliente.' if flags[:empathy]
    points << 'O problema do cliente foi resolvido durante a ligacao.' if flags[:resolved]
    points.presence || ['Atendimento dentro do padrao minimo esperado.']
  end

  def negative_points(flags)
    points = []
    points << 'Atendente usou linguagem inadequada ou agressiva.' if flags[:agent_aggression]
    points << 'Atendente demonstrou sinais de impaciencia durante a conversa.' if flags[:impatience]
    points << 'Ligacao encerrada sem solucao definitiva para o cliente.' if flags[:follow_up] && !flags[:resolved]
    points << 'Detectadas interrupcoes ou sobreposicao de vozes na conversa.' if flags[:interruption]
    points.presence || ['Nenhum desvio critico de protocolo detectado.']
  end

  def improvement_points(flags)
    points = []
    points << 'Trabalhar controle emocional sob situacoes de tensao.' if flags[:agent_aggression]
    points << 'Praticar escuta ativa e evitar atalhos na comunicacao com o cliente.' if flags[:impatience] || flags[:interruption]
    points << 'Acionar o nivel de suporte correto ou escalonar quando necessario.' if flags[:follow_up] && !flags[:resolved]
    points.presence || ['Manter o padrao de atendimento estabelecido.']
  end

  def training_points(flags)
    points = []
    points << 'Reciclagem em etica profissional e atendimento humanizado.' if flags[:agent_aggression]
    points << 'Treinamento em inteligencia emocional no atendimento.' if flags[:impatience]
    points << 'Fluxos de escalonamento e procedimentos de suporte tecnico.' if flags[:follow_up] && !flags[:resolved]
    points.presence || ['Treinamentos periodicos de atualizacao tecnica e comercial.']
  end

  def supervision_alert?(scores, flags)
    flags[:customer_aggression] || flags[:agent_aggression] || flags[:cancel] || flags[:regulatory] || flags[:legal] ||
      scores['nota_final'] < 60 || %w[alto critico].include?(churn_risk(flags)) || %w[alto critico].include?(complaint_risk(flags))
  end

  def alert_reason(scores, flags)
    return 'Cliente demonstrou agressividade durante a ligacao.' if flags[:customer_aggression]
    return 'Atendente tratou o cliente com grosseria ou agressividade.' if flags[:agent_aggression]
    return 'Risco imediato de churn: cliente ameacou cancelar o servico.' if flags[:cancel]
    return 'Alerta regulatorio: cliente mencionou Procon ou Anatel.' if flags[:regulatory]
    return 'Risco juridico: cliente ameacou processo ou citou advogado.' if flags[:legal]
    return "Qualidade do atendimento abaixo do minimo aceitavel (nota: #{scores['nota_final']}/100)." if scores['nota_final'] < 60

    ''
  end

  def summary
    value = @transcript.squish
    value.length > 400 ? "#{value.first(400)}..." : value
  end
end
