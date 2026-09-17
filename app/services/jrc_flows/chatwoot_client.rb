require 'net/http'

class JrcFlows::ChatwootClient
  class Error < StandardError; end

  def initialize(connection, provisioning: false)
    @connection = connection
    @provisioning = provisioning
  end

  def call(method, path, body = nil)
    raise Error, 'Caminho de integração inválido.' unless path.match?(%r{\A[a-z_]+(?:/[a-z_0-9]+)*\z})
    url_path = "/api/v1/accounts/#{@connection.remote_account_id}/#{path}"
    # Stock Chatwoot does not authorize bot tokens for conversation reads or labels.
    # Outgoing messages must use the bot token so human-intervention detection stays correct.
    credential = @provisioning || method == :get || path.end_with?('/labels') ? 'api_token' : 'bot_token'
    token = @connection.secrets[credential]
    raise Error, 'Configure a credencial de acesso ao Chatwoot.' if token.blank?
    headers = { 'api_access_token' => token, 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    local_origin = JSON.parse(ENV.fetch('JRC_FLOWS_LOCAL_ORIGIN_MAP', '{}'))[@connection.base_url]
    if local_origin
      uri = URI(local_origin + url_path)
      klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch, delete: Net::HTTP::Delete }.fetch(method)
      request = klass.new(uri, headers)
      request.body = body.to_json if body
      response = Net::HTTP.start(uri.host, uri.port, open_timeout: 5, read_timeout: 20, use_ssl: uri.scheme == 'https') { |http| http.request(request) }
      raise Error, "Chatwoot recusou a operação (HTTP #{response.code})." unless response.is_a?(Net::HTTPSuccess)
      raw = response.body
    else
      raw = SafeFetch.fetch(@connection.base_url + url_path, method: method, body: body&.to_json, headers: headers,
        sensitive_headers: ['api_access_token'], max_redirects: 0, max_bytes: 2.megabytes, read_timeout: 20,
        validate_content_type: false) { |response| response.tempfile.read }
    end
    raw.blank? ? {} : JSON.parse(raw)
  rescue SafeFetch::Error, JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, IOError, SystemCallError
    raise Error, 'Falha na API do Chatwoot. Verifique endereço, certificado, permissões e disponibilidade.'
  end

  def conversation(id)
    data = call(:get, "conversations/#{Integer(id)}")
    raise Error, 'Conversa fora das caixas autorizadas.' unless @connection.inbox_ids.include?(data['inbox_id'].to_i)
    data
  end

  def message(id, content, private_note: false)
    call(:post, "conversations/#{Integer(id)}/messages", { content: content, message_type: 'outgoing', private: private_note })
  end

  def self.list(data)
    return data if data.is_a?(Array)
    data['payload'] || data['data'] || []
  end
end
