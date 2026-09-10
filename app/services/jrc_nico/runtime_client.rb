require 'net/http'

class JrcNico::RuntimeClient
  class Error < StandardError; end

  KEYS = %w[request_id account_id summary suggested_reply evidence warnings usage model mode].freeze

  def transcribe(payload)
    body = transport('/v1/transcribe', payload.to_json, max_bytes: 5_600_000)
    valid = body.is_a?(Hash) && body.keys.sort == %w[account_id mode model request_id text usage]
    valid &&= body['account_id'] == payload[:account_id] && body['request_id'] == payload[:request_id]
    valid &&= body['mode'] == 'provider' && text?(body['text'], 4000) && text?(body['model'], 150, required: true) && valid_usage?(body)
    raise Error, 'invalid_transcription' unless valid

    body
  end

  def operate(payload)
    body = transport('/v1/operate', payload.to_json)
    fields = payload[:kind] == 'customer' ? %w[reply summary handoff create_lead operator_request] : %w[reply tool arguments]
    raise Error, 'invalid_response' unless body.is_a?(Hash) && body.keys.sort == (fields + %w[request_id account_id usage model mode]).sort
    raise Error, 'invalid_scope' unless body['account_id'] == payload[:account_id] && body['request_id'] == payload[:request_id]
    raise Error, 'invalid_response' unless text?(body['reply'], 4000) && valid_usage?(body) && %w[fixture provider].include?(body['mode'])

    if payload[:kind] == 'customer'
      raise Error, 'invalid_response' unless text?(body['summary'], 8000) && text?(body['operator_request'], 2000) && [true, false].include?(body['handoff']) &&
                                              [true, false].include?(body['create_lead'])
    else
      raise Error, 'invalid_response' unless text?(body['tool'], 80) && text?(body['arguments'], 12_000)

      body['arguments'] = JSON.parse(body['arguments'])
      raise Error, 'invalid_response' unless body['arguments'].is_a?(Hash)
    end
    body
  rescue JSON::ParserError
    raise Error, 'invalid_response'
  rescue Error => e
    Rails.logger.warn("NICO operation failed request_id=#{payload[:request_id]} code=#{e.message}")
    raise
  end

  def analyze(run, context)
    payload = { request_id: run.request_id, account_id: run.account_id, agent_key: run.agent_key, message: run.message, context: context, history: [] }.to_json
    validate!(transport('/v1/analyze', payload), run, context)
  end

  private

  def transport(path, payload, max_bytes: 262_144)
    uri = URI(ENV.fetch('NICO_RUNTIME_URL'))
    token = ENV.fetch('NICO_SERVICE_TOKEN')
    raise Error, 'invalid_configuration' unless %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil? && token.length >= 32

    raise Error, 'context_too_large' if payload.bytesize > max_bytes

    request = Net::HTTP::Post.new(path, { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' })
    request.body = payload
    body = +''
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 3, read_timeout: 55, write_timeout: 10) do |http|
      http.request(request) do |response|
        raise Error, "runtime_http_#{response.code}" unless response.code == '200'

        response.read_body do |chunk|
          body << chunk
          raise Error, 'invalid_response' if body.bytesize > 131_072
        end
      end
    end
    JSON.parse(body)
  rescue KeyError, URI::InvalidURIError, JSON::ParserError, IOError, SystemCallError, Timeout::Error => e
    raise Error, e.class.name
  end

  private

  def validate!(body, run, context)
    valid = body.is_a?(Hash) && body.keys.sort == KEYS.sort
    valid &&= body['account_id'] == run.account_id && body['request_id'] == run.request_id
    valid &&= text?(body['summary'], 8000, required: true) && text?(body['suggested_reply'], 4000) && text?(body['model'], 150, required: true)
    valid &&= %w[fixture provider].include?(body['mode'])
    valid &&= body['warnings'].is_a?(Array) && body['warnings'].length <= 10 && body['warnings'].all? { |warning| text?(warning, 1000) }
    valid &&= body['evidence'].is_a?(Array) && body['evidence'].length <= 30
    allowed = context.values.flatten.map { |item| item.stringify_keys.slice('source', 'reference') }
    valid &&= body['evidence'].all? { |item| item.is_a?(Hash) && item.keys.sort == %w[reference source] && allowed.include?(item) }
    valid &&= valid_usage?(body)
    raise Error, 'invalid_response' unless valid

    body
  end

  def text?(value, max, required: false)
    value.is_a?(String) && value.length <= max && (!required || value.present?)
  end

  def valid_usage?(body)
    usage = body['usage']
    return usage.nil? if body['mode'] == 'fixture'
    return false unless usage.is_a?(Hash) && usage.keys.sort == %w[input_tokens output_tokens total_tokens]
    return false unless usage.values.all? { |value| value.is_a?(Integer) && value.between?(0, 270_000) }

    usage['input_tokens'] + usage['output_tokens'] == usage['total_tokens']
  end
end
