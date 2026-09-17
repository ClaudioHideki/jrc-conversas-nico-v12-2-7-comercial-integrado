class JrcFlows::EventsController < ActionController::API
  before_action { head :not_found unless JrcFlows::Access.external_beta? }
  def create
    connection = JrcFlowConnection.find_by!(public_id: params[:public_id])
    return head :service_unavailable unless connection.enabled? && JrcFlows::Access.enabled?(connection.account)
    raw = request.raw_post
    return head :payload_too_large if raw.bytesize > 2.megabytes
    secret = connection.secrets['webhook_secret']
    timestamp = request.headers['X-Chatwoot-Timestamp'].to_s
    signature = request.headers['X-Chatwoot-Signature'].to_s
    valid_time = timestamp.match?(/\A\d{10}\z/) && (Time.now.to_i - timestamp.to_i).abs <= 300
    return head :unauthorized unless secret.present? && valid_time
    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{raw}")}"
    return head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(signature, expected)

    payload = JSON.parse(raw)
    return head :forbidden unless payload.dig('account', 'id').to_i == connection.remote_account_id
    event_name = payload['event']
    return head :accepted unless %w[message_created conversation_updated conversation_status_changed conversation_resolved conversation_opened].include?(event_name)
    conversation = payload['conversation'] || payload
    inbox_id = (payload.dig('inbox', 'id') || conversation['inbox_id']).to_i
    return head :forbidden unless connection.inbox_ids.include?(inbox_id)
    return head :bad_request unless conversation['id'].to_i.positive?
    if event_name == 'message_created'
      return head :bad_request unless payload['id'].to_i.positive?
      type = payload['message_type']
      human = ['outgoing', 1].include?(type) && payload.dig('sender', 'type') == 'user'
      incoming = ['incoming', 0].include?(type) && !payload['private']
      if human
        connection.remote_sessions.where(conversation_id: conversation['id'], status: %w[ready running waiting delayed]).update_all(
          status: 'paused', error: 'Atendente respondeu no Chatwoot.', wake_at: nil, finished_at: Time.current)
      end
      return head :accepted unless incoming || human
    end
    key = event_name == 'message_created' ? "message:#{payload['id']}" : Digest::SHA256.hexdigest(raw)
    record = connection.remote_events.create!(event_key: key, payload: payload)
    JrcFlows::RemoteEventJob.perform_later(record.id)
    head :accepted
  rescue ActiveRecord::RecordNotUnique
    head :accepted
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue JSON::ParserError, TypeError, NoMethodError
    head :bad_request
  end
end
