require 'net/http'

class JrcNico::ErpClient
  class Error < StandardError; end

  def call(path, payload)
    raise Error, 'invalid_route' unless %w[resolve context].include?(path)

    uri = URI(ENV.fetch('NICO_ERP_URL', 'http://erp:3112'))
    raise Error, 'invalid_configuration' unless %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil?

    request = Net::HTTP::Post.new("/#{path}", 'Authorization' => "Bearer #{ENV.fetch('NICO_SERVICE_TOKEN')}", 'Content-Type' => 'application/json')
    request.body = payload.to_json
    body = +''
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 3, read_timeout: 30, write_timeout: 5) do |http|
      http.request(request) do |response|
        raise Error, 'erp_unavailable' unless response.code == '200'

        response.read_body do |chunk|
          body << chunk
          raise Error, 'response_too_large' if body.bytesize > 65_536
        end
      end
    end
    JSON.parse(body)
  rescue KeyError, URI::InvalidURIError, JSON::ParserError, IOError, SystemCallError, Timeout::Error
    raise Error, 'erp_unavailable'
  end
end
