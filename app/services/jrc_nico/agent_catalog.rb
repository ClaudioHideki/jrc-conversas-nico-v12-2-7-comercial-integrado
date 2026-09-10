class JrcNico::AgentCatalog
  AGENTS = [
    { key: 'nico', name: 'NICO — Copiloto JRC', description: 'Resumo, resposta sugerida e próximos passos com fontes.',
      limitation: 'O NICO sugere o especialista em mensagens novas; análises e envios dependem de autorização humana.', actions: %w[follow_up task] },
    { key: 'comercial', name: 'Comercial', description: 'Qualificação assistida e análise do CRM autorizado.',
      limitation: 'Oportunidades e atividades exigem revisão humana.', actions: %w[follow_up task create_deal] },
    { key: 'cx', name: 'CX', description: 'Sinais de insatisfação, pendências e proposta de recuperação.',
      limitation: 'Sem coleta automática de NPS ou modelo de churn validado.', actions: %w[follow_up task] },
    { key: 'suporte_n1', name: 'Suporte N1', description: 'Orientação baseada em procedimentos aprovados.',
      limitation: 'Tarefa interna no CRM; abertura em Help Desk e diagnóstico remoto dependem de integração.', actions: %w[task follow_up] },
    { key: 'financeiro', name: 'Financeiro', description: 'Preparação assistida de atendimento financeiro.',
      limitation: 'Leitura ERP exige vínculo autorizado. Segunda via, negociação e cobrança agendada não habilitadas.', actions: %w[task] },
    { key: 'implantacao', name: 'Implantação', description: 'Checklist sugerido e acompanhamento de pendências.',
      limitation: 'Sem provisionamento de PABX, portabilidade ou confirmação automática de etapas.', actions: %w[task follow_up] },
    { key: 'supervisor', name: 'Supervisor', description: 'Revisão de riscos e recomendação de encaminhamento na conversa.',
      limitation: 'Sem orquestração global. Use os controles do JRC para cancelar e atribuir ao humano.', actions: %w[task] }
  ].map(&:freeze).freeze
  KEYS = AGENTS.pluck(:key).freeze

  def self.for_account(account)
    return [] unless account.custom_attributes['nico_enabled'] == true

    enabled = account.custom_attributes.fetch('nico_agent_keys', KEYS)
    AGENTS.select { |agent| Array(enabled).include?(agent[:key]) }
  end

  def self.fetch(key)
    AGENTS.find { |agent| agent[:key] == key } || raise(ArgumentError, 'unknown_agent')
  end
end
