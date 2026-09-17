class JrcFlows::WorkflowEngine
  class Error < StandardError; end
  class SimulationBlocked < Error; end
  attr_reader :trace

  def initialize(flow, simulation: false, depth: 0, guard: nil)
    @flow, @simulation, @depth, @guard = flow, simulation, depth, guard
    @workflow = flow.source_definition
    @outputs, @trace, @memory = {}, [], {}
  end

  def perform(payload)
    errors = JrcFlows::WorkflowDefinition.new(@flow).errors(complete: !@simulation)
    raise Error, errors.join(' ') if errors.any?
    raise Error, 'Limite de quatro subworkflows encadeados.' if @depth > 4

    start = @workflow['nodes'].find { |node| JrcFlows::WorkflowDefinition::STARTS.include?(node['type']) }
    raise Error, 'Selecione um nó de entrada.' unless start

    @queue = [[start['name'], [{ 'json' => { 'body' => payload }.merge(payload) }]]]
    last = []
    until @queue.empty?
      raise Error, 'Limite de 200 passos por turno.' if @trace.length >= 200
      name, input = @queue.shift
      node = @workflow['nodes'].find { |n| n['name'] == name }
      raise Error, 'Execução interrompida: fluxo pausado ou atendimento assumido.' if @guard && !@guard.call(node)
      @trace << { node_id: node['id'], label: name, type: node['type'], at: Time.current.iso8601 }
      @input = input
      output, port = node['disabled'] ? [input, 0] : execute_with_error_handling(node)
      raise Error, "#{name}: saída inválida (esperada lista de itens JSON)." unless output.is_a?(Array) && output.size <= 100 && output.all? { |item| item.is_a?(Hash) && item['json'].is_a?(Hash) }

      @outputs[name] = output
      last = output
      break if node['type'] == 'n8n-nodes-base.respondToWebhook'

      connections = @workflow['connections'].dig(name, 'main', port) || []
      connections.each { |edge| @queue << [edge['node'], output] }
    end
    { status: 'completed', trace: trace, output: last.first&.fetch('json', {}) || {} }
  rescue StandardError => e
    raise Error, "#{@trace.last&.fetch(:label, nil)}: #{e.is_a?(Error) || e.is_a?(JrcFlows::Javascript::Error) ? e.message : 'falha na execução do nó.'}" unless @simulation

    { status: 'failed', trace: trace + [{ label: 'Falha', type: 'error', content: e.message.to_s.first(500) }], output: nil }
  end

  private

  def resolve(parameters)
    JrcFlows::Javascript.evaluate(code: '', input: @input, outputs: @outputs, parameters: parameters)
  end

  def execute_with_error_handling(node)
    execute(node)
  rescue SimulationBlocked
    raise
  rescue StandardError => e
    raise unless node['continueOnFail'] || node['onError'] == 'continueRegularOutput'

    @trace.last[:content] = 'Falha encaminhada para o tratamento de erro do workflow.'
    message = e.is_a?(Error) ? e.message.first(350) : 'Falha na integração do nó.'
    [[{ 'json' => { 'error' => { 'message' => message } } }], 0]
  end

  def execute(node)
    type = node['type'].delete_prefix('n8n-nodes-base.')
    raw = node['parameters']
    return [JrcFlows::Javascript.evaluate(code: raw.fetch('jsCode'), input: @input, outputs: @outputs), 0] if type == 'code'

    p = resolve(raw)
    case type
    when 'webhook', 'executeWorkflowTrigger', 'noOp', 'stickyNote' then [@input, 0]
    when 'if' then [@input, condition(p.fetch('conditions')) ? 0 : 1]
    when 'switch'
      index = p.fetch('rules').fetch('values').index { |rule| condition(rule.fetch('conditions')) }
      index ||= p.dig('options', 'fallbackOutput') == 'extra' ? p['rules']['values'].size : p['rules']['values'].size + 1
      [@input, index]
    when 'redis' then [redis(p), 0]
    when 'respondToWebhook'
      body = p['responseBody'] || @input.first.fetch('json')
      body = JSON.parse(body) if body.is_a?(String)
      [[{ 'json' => body }], 0]
    when 'set'
      values = p.dig('assignments', 'assignments') || []
      [@input.map { |i| { 'json' => i['json'].merge(values.to_h { |v| [v['name'], v['value']] }) } }, 0]
    when 'httpRequest' then [[{ 'json' => http_request(p) }], 0]
    when 'executeWorkflow'
      child = @flow.sibling_flows.find_by(id: p['jrc_flow_id'], engine: 'workflow')
      raise Error, 'Importe e selecione o subworkflow correspondente no JRC.' unless child && child.id != @flow.id
      result = self.class.new(child, simulation: @simulation, depth: @depth + 1, guard: @guard).perform(@input.first.fetch('json'))
      @trace.concat(result[:trace])
      raise Error, 'O subworkflow falhou.' unless result[:status] == 'completed'

      [[{ 'json' => result.fetch(:output) }], 0]
    when '@n8n/n8n-nodes-langchain.agent' then [[{ 'json' => { 'output' => agent(node, p) } }], 0]
    else raise Error, "Tipo #{type} ainda não suportado pelo JRC."
    end
  end

  def condition(group)
    values = group.fetch('conditions').map do |c|
      a, b = c.values_at('leftValue', 'rightValue')
      a, b = a.downcase, b.downcase if group.dig('options', 'caseSensitive') == false && a.is_a?(String) && b.is_a?(String)
      case c.dig('operator', 'operation')
      when 'true' then a == true
      when 'false' then a == false
      when 'equals', 'equal' then a == b
      when 'notEquals' then a != b
      when 'contains' then a.to_s.include?(b.to_s)
      when 'notContains' then !a.to_s.include?(b.to_s)
      when 'startsWith' then a.to_s.start_with?(b.to_s)
      when 'empty' then a.blank?
      when 'notEmpty' then a.present?
      when 'exists' then !a.nil?
      when 'notExists' then a.nil?
      when 'gt' then Float(a) > Float(b)
      when 'gte' then Float(a) >= Float(b)
      when 'lt' then Float(a) < Float(b)
      when 'lte' then Float(a) <= Float(b)
      else raise Error, 'Operador de comparação ainda não suportado.'
      end
    end
    group['combinator'] == 'or' ? values.any? : values.all?
  end

  def redis(p)
    # Keys from imported workflows cannot read or overwrite another tenant's data.
    key = "jrc:flows:#{@flow.account_id}:#{@flow.id}:#{Digest::SHA256.hexdigest(p.fetch('key').to_s)}"
    value = @simulation ? @memory[key] : Redis::Alfred.get(key)
    case p['operation']
    when 'get' then @input.map { |i| { 'json' => i['json'].merge(p.fetch('propertyName', 'value') => value) } }
    when 'set'
      value = p.fetch('value').to_s
      raise Error, 'Memória excedeu 100 KB.' if value.bytesize > 100_000

      if @simulation
        @memory[key] = value
      else
        Redis::Alfred.setex(key, value, p.fetch('ttl', 604_800).to_i.clamp(1, 604_800))
      end
      @input
    when 'delete'
      @simulation ? @memory.delete(key) : Redis::Alfred.delete(key)
      @input
    else raise Error, 'Operação de memória não suportada.'
    end
  end

  def agent(node, params)
    model_name = @workflow['connections'].find { |_, groups| groups.fetch('ai_languageModel', []).flatten.any? { |e| e['node'] == node['name'] } }&.first
    model_node = @workflow['nodes'].find { |n| n['name'] == model_name }
    raise Error, 'Conecte um modelo OpenAI ao agente.' unless model_node
    raise SimulationBlocked, 'O Playground parou antes da IA: nenhuma chamada externa foi feita. Ative em uma caixa de teste para execução real.' if @simulation

    model = resolve(model_node['parameters'])
    model_id = model['model'].is_a?(Hash) ? model['model']['value'] : model['model']
    key = @flow.effective_secrets['openai_api_key']
    raise Error, 'Configure a chave OpenAI no JRC.' if key.blank?

    body = { model: model_id, messages: [{ role: 'system', content: params.dig('options', 'systemMessage').to_s },
                                        { role: 'user', content: params.fetch('text').to_s }], max_completion_tokens: 2500 }
    body[:temperature] = model.dig('options', 'temperature') if model.dig('options', 'temperature')
    result = fetch_json('https://api.openai.com/v1/chat/completions', :post, body.to_json, 'Authorization' => "Bearer #{key}")
    result.fetch('choices').first.fetch('message').fetch('content')
  end

  def http_request(p)
    raise SimulationBlocked, 'O Playground parou antes da API: nenhuma chamada externa foi feita.' if @simulation

    uri = URI(p.fetch('url'))
    raise Error, 'Use URL HTTPS pública sem credenciais no endereço.' unless uri.is_a?(URI::HTTPS) && uri.userinfo.nil?

    headers = {}
    Array(p.dig('headerParameters', 'parameters')).each { |h| headers[h.fetch('name')] = h.fetch('value').to_s } if p['sendHeaders']
    if p['jrc_use_credential']
      key = @flow.effective_secrets['http_api_key']
      raise Error, 'Configure a credencial HTTP no JRC.' if key.blank?
      headers[p.fetch('jrc_auth_header', 'Authorization')] = key
    elsif p['authentication'].present? && p['authentication'] != 'none'
      raise Error, 'Mapeie a autenticação deste nó para a credencial HTTP do JRC.'
    end
    method = p.fetch('method', 'GET').downcase.to_sym
    raise Error, 'Método HTTP não suportado.' unless %i[get post put patch delete].include?(method)
    body = p['jsonBody']
    body = body.to_json if body.is_a?(Hash) || body.is_a?(Array)
    result = fetch_json(uri.to_s, method, p['sendBody'] ? body : nil, headers)
    result.is_a?(Hash) ? result : { 'data' => result }
  end

  def fetch_json(url, method, body, headers)
    SafeFetch.fetch(url, method: method, body: body, headers: { 'Content-Type' => 'application/json' }.merge(headers),
      sensitive_headers: headers.keys, max_redirects: 0, max_bytes: 200_000, read_timeout: 55,
      validate_content_type: false) { |result| JSON.parse(result.tempfile.read) }
  rescue SafeFetch::Error, JSON::ParserError
    raise Error, 'A API não retornou JSON válido ou recusou a conexão. Confira URL e credenciais.'
  end
end
