class Whatsapp::CallingConfigurationTestService
  class Error < StandardError; end

  GRAPH_API_VERSION = 'v22.0'.freeze
  PHONE_NUMBER_FIELDS = 'id,display_phone_number,verified_name,code_verification_status,account_mode'.freeze
  WABA_FIELDS = 'id'.freeze
  WABA_PHONE_NUMBER_FIELDS = 'id,display_phone_number,verified_name,account_mode'.freeze
  SANDBOX_PHONE_NUMBER_FILTER = '[{"field":"account_mode","operator":"EQUAL","value":"SANDBOX"}]'.freeze

  def initialize(configuration)
    @configuration = configuration
  end

  def perform
    validate_access_token!
    validate_waba_access!
    phone_data = fetch_phone_number!
    waba_phone_numbers = fetch_waba_phone_numbers!
    validate_waba_phone_number_match!(phone_data, waba_phone_numbers)
    validate_calling_settings!

    true
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, HTTParty::Error
    raise Error, 'Não foi possível consultar a Meta. Tente novamente.'
  end

  private

  attr_reader :configuration

  def validate_access_token!
    graph_get('me', { fields: 'id' }, 'Access Token inválido ou expirado')
  end

  def validate_waba_access!
    data = graph_get(configuration.waba_id, { fields: WABA_FIELDS }, 'Não foi possível acessar o WABA ID informado')
    return if data['id'].to_s == configuration.waba_id.to_s

    raise Error, 'A Meta retornou um WABA ID diferente do informado.'
  end

  def fetch_phone_number!
    data = graph_get(
      configuration.phone_number_id,
      { fields: PHONE_NUMBER_FIELDS },
      'Não foi possível acessar diretamente o Phone Number ID informado'
    )
    return data if data['id'].to_s == configuration.phone_number_id.to_s

    raise Error, 'A Meta retornou um Phone Number ID diferente do informado.'
  end

  def fetch_waba_phone_numbers!
    regular_numbers = fetch_waba_phone_numbers_page
    return regular_numbers if phone_number_listed?(regular_numbers)

    sandbox_numbers = fetch_sandbox_waba_phone_numbers

    (regular_numbers + sandbox_numbers).uniq { |phone| phone['id'].to_s }
  end

  def fetch_waba_phone_numbers_page(extra_query = {})
    data = graph_get(
      "#{configuration.waba_id}/phone_numbers",
      { fields: WABA_PHONE_NUMBER_FIELDS, limit: 100 }.merge(extra_query),
      'Não foi possível listar os Phone Number IDs do WABA informado'
    )

    Array(data['data'])
  end

  def fetch_sandbox_waba_phone_numbers
    response = graph_get_response(
      "#{configuration.waba_id}/phone_numbers",
      { fields: WABA_PHONE_NUMBER_FIELDS, limit: 100, filtering: SANDBOX_PHONE_NUMBER_FILTER }
    )
    return Array(response.parsed_response['data']) if response.success? && response.parsed_response.is_a?(Hash)

    return [] if sandbox_filter_unsupported?(response)

    raise Error,
          "Não foi possível listar os Phone Number IDs SANDBOX do WABA informado: #{meta_error_message(response)}"
  end

  def phone_number_listed?(phone_numbers)
    phone_numbers.any? { |phone| phone['id'].to_s == configuration.phone_number_id.to_s }
  end

  def validate_waba_phone_number_match!(phone_data, waba_phone_numbers)
    return if phone_number_listed?(waba_phone_numbers)

    validate_local_inbox_match!
    return if sandbox_phone_number?(phone_data) && local_matching_inbox?

    raise Error, 'O Phone Number ID informado não pertence ao WABA ID informado.'
  end

  def validate_local_inbox_match!
    mismatched_inbox = matching_whatsapp_cloud_channels.find do |channel|
      channel.provider_config['business_account_id'].present? &&
        channel.provider_config['business_account_id'].to_s != configuration.waba_id.to_s
    end
    return unless mismatched_inbox

    raise Error, 'A Caixa de Entrada WhatsApp Cloud associada usa outro WABA ID.'
  end

  def validate_calling_settings!
    data = graph_get(
      "#{configuration.phone_number_id}/settings",
      { fields: 'calling' },
      'Não foi possível consultar os Call Settings do Phone Number ID informado'
    )
    return if data.dig('calling', 'status').present?

    raise Error, 'A Meta não retornou o status de Calling nos Call Settings do Phone Number ID informado.'
  end

  def graph_get(path, query, failure_prefix)
    response = graph_get_response(path, query)

    parsed_response = response.parsed_response
    return parsed_response if response.success? && parsed_response.is_a?(Hash)

    raise Error, "#{failure_prefix}: #{meta_error_message(response)}"
  end

  def graph_get_response(path, query)
    HTTParty.get(
      "#{base_url}/#{api_version}/#{path}",
      headers: { 'Authorization' => "Bearer #{configuration.access_token}" },
      query: query,
      timeout: 10
    )
  end

  def meta_error_message(response)
    parsed_response = response.parsed_response
    error = parsed_response['error'] if parsed_response.is_a?(Hash)
    return response.body.to_s.presence || 'erro desconhecido da Meta' unless error.is_a?(Hash)

    error['error_user_msg'].presence || error['message'].presence || error['error_user_title'].presence ||
      response.body.to_s.presence || 'erro desconhecido da Meta'
  end

  def matching_whatsapp_cloud_channels
    @matching_whatsapp_cloud_channels ||= configuration.account.inboxes.includes(:channel).filter_map do |inbox|
      channel = inbox.channel
      next unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'
      next unless channel.provider_config['phone_number_id'].to_s == configuration.phone_number_id.to_s

      channel
    end
  end

  def local_matching_inbox?
    matching_whatsapp_cloud_channels.any?
  end

  def sandbox_phone_number?(phone_data)
    phone_data['account_mode'].to_s.casecmp('SANDBOX').zero?
  end

  def sandbox_filter_unsupported?(response)
    parsed_response = response.parsed_response
    error = parsed_response['error'] if parsed_response.is_a?(Hash)
    return false unless error.is_a?(Hash)

    message = [
      error['message'],
      error['error_user_msg'],
      error['error_user_title'],
      error['type']
    ].compact.join(' ').downcase

    message.match?(/account_mode|filtering|filter/) &&
      message.match?(/unsupported|not supported|beta|unknown|invalid parameter/)
  end

  def api_version
    GRAPH_API_VERSION
  end

  def base_url
    ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end
end
