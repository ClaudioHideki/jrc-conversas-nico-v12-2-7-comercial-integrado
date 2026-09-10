class Hodupbx::CallHistoryService
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: :provider_error)
      @code = code
      super(message)
    end
  end

  REQUEST_TIMEOUT = 20
  EMPTY_VALUES = ['', '-', ' - ', 'N/A', '00-00-0000 00:00:00'].freeze

  def initialize(integration:, extension:, start_date:, end_date:)
    @integration = integration
    @extension = extension.to_s
    @start_date = start_date
    @end_date = end_date
  end

  def call
    validate_configuration!
    response = perform_request
    payload = parse_payload(response)
    validate_payload!(response, payload)

    calls = Array(payload['data']).map { |record| normalize(record) }
    { count: calls.size, calls: calls }
  rescue Timeout::Error
    raise Error.new('Tempo limite ao consultar o PABX', code: :timeout)
  rescue SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError
    raise Error.new('PABX indisponível', code: :unavailable)
  end

  private

  def validate_configuration!
    raise Error.new('Histórico desativado', code: :history_disabled) unless @integration.history_enabled?
    raise Error.new('Configuração incompleta', code: :configuration_missing) if @integration.cdr_token.blank? || @extension.blank?
  end

  def perform_request
    Rails.logger.info(
      "[HoduPBX CallLog] extension=#{@extension} start_date=#{@start_date.strftime('%d-%m-%Y')} end_date=#{@end_date.strftime('%d-%m-%Y')}"
    )
    HTTParty.post(
      endpoint,
      body: { token_id: @integration.cdr_token, number: @extension }.to_json,
      headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' },
      timeout: REQUEST_TIMEOUT
    )
  end

  def endpoint
    base = @integration.cdr_base_url.delete_suffix('/')
    version = @integration.cdr_api_version.delete_prefix('/').delete_suffix('/')
    tenant = @integration.tenant_type.upcase
    start_value = @start_date.strftime('%d-%m-%Y')
    end_value = @end_date.strftime('%d-%m-%Y')
    "#{base}/hodupbx_api/#{version}/api/info/#{start_value}/#{end_value}/#{tenant}/callLog"
  end

  def parse_payload(response)
    parsed = response.parsed_response
    parsed = JSON.parse(parsed) if parsed.is_a?(String)
    raise JSON::ParserError unless parsed.is_a?(Hash)

    parsed
  rescue JSON::ParserError, TypeError
    raise Error.new('Resposta inválida do PABX', code: :invalid_response)
  end

  def validate_payload!(response, payload)
    return if empty_call_log_response?(response, payload)

    unless response.success?
      code = [401, 403, 412].include?(response.code) ? :invalid_credentials : :provider_error
      raise Error.new('Falha na consulta ao PABX', code: code)
    end
    return if payload['status'].to_s.casecmp('SUCCESS').zero?

    raise Error.new('A API do PABX rejeitou a consulta', code: :invalid_credentials)
  end

  def empty_call_log_response?(response, payload)
    response.code == 411 && payload['message'].to_s.include?('Call Log Details Not Found')
  end

  def normalize(record)
    direction = normalized_direction(record['call_direction'])
    identity_fields(record, direction)
      .merge(timing_fields(record))
      .merge(outcome_fields(record))
  end

  def identity_fields(record, direction)
    {
      id: nullable(record['callid']),
      unique_id: nullable(record['unique_token']),
      extension: @extension,
      direction: direction,
      caller: party(record['caller'], record['caller_name']),
      callee: party(record['callee'], record['callee_name']),
      external_number: external_number(record, direction),
      did: nullable(record['did'])
    }
  end

  def timing_fields(record)
    {
      started_at: normalized_time(record['start_date']),
      answered_at: normalized_time(record['answer_time']),
      ended_at: normalized_time(record['end_date']),
      total_duration_seconds: duration(record['call_sec'], record['call_minute']),
      talk_duration_seconds: duration(record['answer_sec'], record['answer_minute'])
    }
  end

  def outcome_fields(record)
    {
      status: normalized_status(record['call_status'], record['hangup_reason']),
      hangup_by: nullable(record['hangup_by'])&.downcase,
      hangup_reason: nullable(record['hangup_reason']),
      recording_url: recording_url(record['call_rec_path'])
    }
  end

  def party(number, name)
    { number: nullable(number), name: nullable(name) }
  end

  def nullable(value)
    normalized = value.to_s.strip
    EMPTY_VALUES.include?(normalized) ? nil : normalized
  end

  def normalized_direction(value)
    { 'OUTBOUND' => 'outbound', 'INBOUND' => 'inbound', 'LOCAL' => 'local' }.fetch(value.to_s.upcase, 'unknown')
  end

  def normalized_status(status, reason)
    value = status.to_s.downcase
    return 'answered' if value == 'answered'
    return 'busy' if reason.to_s.upcase.include?('BUSY')
    return 'cancelled' if value.include?('cancel')
    return 'failed' if value.include?('fail')

    'unanswered'
  end

  def normalized_time(value)
    raw = nullable(value)
    return if raw.blank?

    Time.zone.strptime(raw, '%d-%m-%Y %H:%M:%S').iso8601
  rescue ArgumentError, TypeError
    begin
      Time.zone.parse(raw)&.iso8601
    rescue ArgumentError, TypeError
      nil
    end
  end

  def duration(seconds, minutes)
    return seconds.to_i if nullable(seconds)

    (minutes.to_f * 60).to_i
  end

  def external_number(record, direction)
    return nullable(record['callee']) if direction == 'outbound'
    return nullable(record['caller']) if direction == 'inbound'

    caller = nullable(record['caller'])
    caller == @extension ? nullable(record['callee']) : caller
  end

  def recording_url(value)
    raw = nullable(value)
    return if raw.blank?

    uri = URI.parse(raw)
    raw if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end
end
