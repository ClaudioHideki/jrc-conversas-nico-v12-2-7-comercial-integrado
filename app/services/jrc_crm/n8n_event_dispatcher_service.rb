module JrcCrm
  class N8nEventDispatcherService
    def initialize(account_id:, resource_type:, resource_id:, event_name:)
      @account = Account.find(account_id)
      @resource_type = resource_type
      @resource_id = resource_id
      @event_name = event_name
    end

    def call
      webhook_url = ENV.fetch('JRC_CRM_N8N_WEBHOOK_URL', nil)
      return unless webhook_url

      token = 'JRC_CRM_N8N_TOKEN' # Placeholder for real token logic
      
      resource_class = "JrcCrm::#{@resource_type}".constantize
      resource = resource_class.find_by(id: @resource_id, account_id: @account.id)
      
      return unless resource

      payload = {
        event: @event_name,
        account_id: @account.id,
        resource_type: @resource_type,
        resource_id: @resource_id,
        data: serialize_resource(resource),
        timestamp: Time.current.iso8601
      }

      dispatch_http_request(webhook_url, payload, token)
    end

    private

    def serialize_resource(resource)
      resource.as_json
    end

    def dispatch_http_request(url, payload, token)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')

      request = Net::HTTP::Post.new(uri.path, {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{token}"
      })
      request.body = payload.to_json

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("N8n dispatch failed: #{response.code} #{response.message}")
      end
    rescue StandardError => e
      Rails.logger.error("N8n dispatch exception: #{e.message}")
    end
  end
end
