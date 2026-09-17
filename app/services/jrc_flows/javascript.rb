require 'net/http'

class JrcFlows::Javascript
  class Error < StandardError; end

  def self.evaluate(code:, input:, outputs: {}, parameters: nil)
    # Deployment-owned internal service. No flow or user can override this address.
    uri = URI(ENV.fetch('JRC_FLOWS_SANDBOX_URL'))
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{ENV.fetch('JRC_FLOWS_SANDBOX_TOKEN')}")
    request.body = { code: code, input: input, outputs: outputs, parameters: parameters }.to_json
    raise Error, 'Entrada JavaScript excedeu 2 MB.' if request.body.bytesize > 2.megabytes

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 2, read_timeout: 6) { |http| http.request(request) }
    raise Error, 'Falha no serviço interno JavaScript.' unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch('result')
  rescue JSON::ParserError, KeyError, IOError, SystemCallError, Net::ReadTimeout, Net::OpenTimeout
    raise Error, 'Execução JavaScript indisponível ou interrompida. Verifique o serviço interno Flows.'
  end
end
