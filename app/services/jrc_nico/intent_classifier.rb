class JrcNico::IntentClassifier
  INTENTS = {
    'financeiro' => /\b(fatura|boleto|cobran[cç]a|pagamento|vencimento|segunda via|inadimpl|financeir)/i,
    'cx' => /\b(reclama[cç][aã]o|insatisfeit|cancelar|cancelamento|péssim|ruim|demora|atraso)/i,
    'suporte_n1' => /\b(erro|falha|problema|suporte|chamado|n[aã]o funciona|sem (?:a[uú]dio|sinal)|ramal|internet)/i,
    'implantacao' => /\b(implanta[cç][aã]o|instala[cç][aã]o|portabilidade|treinamento|ativa[cç][aã]o|configura[cç][aã]o)/i,
    'comercial' => /\b(comprar|contratar|pre[cç]o|or[cç]amento|proposta|plano|produto|vendas?|comercial|demonstra[cç][aã]o)/i
  }.freeze

  CNPJ_PATTERN = %r{(?<!\d)(\d{2}[.\s]?\d{3}[.\s]?\d{3}[/-]?\d{4}-?\d{2})(?!\d)}

  def self.call(message)
    text = message.content.to_s.squish.first(4000)
    matches = INTENTS.filter_map { |key, pattern| key if text.match?(pattern) }
    agent_key = matches.first || 'nico'
    cnpj = text[CNPJ_PATTERN]&.gsub(/\D/, '')
    company_name = text[/\b(?:empresa|cliente)\s+([\p{L}\d][\p{L}\d .&-]{2,80})/i, 1]&.strip
    {
      'message_id' => message.id,
      'agent_key' => agent_key,
      'intent' => agent_key,
      'confidence' => if matches.one?
                        'high'
                      else
                        (matches.many? ? 'medium' : 'low')
                      end,
      'cnpj' => cnpj,
      'company_name' => company_name,
      'status' => 'pending',
      'detected_at' => Time.current.iso8601,
      'reason' => matches.any? ? "Termos compatíveis com #{matches.join(', ')}" : 'Assunto ainda não determinado'
    }.compact
  end
end
