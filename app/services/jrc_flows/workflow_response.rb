class JrcFlows::WorkflowResponse
  def self.normalize(result)
    raise JrcFlows::WorkflowEngine::Error, 'Saída inválida: esperado objeto JSON.' unless result.is_a?(Hash)
    if result.key?('mensagem')
      raise JrcFlows::WorkflowEngine::Error, 'O workflow retornou um erro de integração.' if result['ok_ligo'] == 'NAO' || result['acao'] == 'ERRO' || result['erro'].present?
      raise JrcFlows::WorkflowEngine::Error, 'A transferência para outro bot (ex.: MOCCHI) exige um adaptador próprio no JRC.' if result['acao'] == 'TRANSFERIR_BOT'

      response = { 'messages' => [result['mensagem'], result['mensagem_2']].compact_blank,
        'handoff' => result['transferir_ligo'] == 'SIM' || result['acao'] == 'TRANSFERIR_HUMANO',
        'destination' => result['destino'].to_s, 'summary' => result['resumo_handoff'].to_s,
        'close' => result['encerrar_ligo'] == 'SIM' || result['acao'] == 'ENCERRAR',
        'ignore' => result['ignorar_ligo'] == 'SIM' || result['acao'] == 'IGNORAR' }
    else
      response = result.slice('messages', 'destination', 'summary').merge('handoff' => result['handoff'] == true, 'close' => result['close'] == true, 'ignore' => result['ignore'] == true)
    end
    unless response['messages'].is_a?(Array) && response['messages'].size <= 10 && response['messages'].all? { |s| s.is_a?(String) && s.size <= 10_000 }
      raise JrcFlows::WorkflowEngine::Error, 'A saída deve conter messages: lista de até 10 textos, com até 10.000 caracteres cada.'
    end
    response
  end
end
