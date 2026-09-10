# rubocop:disable Metrics/ModuleLength
module Enterprise::Whatsapp::Providers::WhatsappCloudService
  # Calls API + the call_permission_request interactive message both require Graph
  # API v17+; OSS phone_id_path is locked at v13.0 for legacy /messages compatibility.
  # Use the configured global version (defaulting to v22.0) for call-flow endpoints.
  WHATSAPP_CALLING_API_VERSION_FALLBACK = 'v22.0'.freeze

  def pre_accept_call(call_id, sdp_answer)
    call_api('pre_accept_call', call_action_body(call_id, 'pre_accept', sdp_answer))
  end

  def accept_call(call_id, sdp_answer)
    call_api('accept_call', call_action_body(call_id, 'accept', sdp_answer))
  end

  def reject_call(call_id)
    call_api('reject_call', call_action_body(call_id, 'reject'))
  end

  def terminate_call(call_id)
    call_api('terminate_call', call_action_body(call_id, 'terminate'))
  end

  def send_call_permission_request(to_phone_number, body_text = I18n.t('conversations.messages.whatsapp.call_permission_request_body'))
    response = HTTParty.post(
      "#{calls_phone_id_path}/messages", headers: calling_api_headers, body: permission_request_body(to_phone_number, body_text)
    )

    unless response.success?
      Rails.logger.error "[WHATSAPP CALL] send_call_permission_request failed: status=#{response.code} body=#{response.body}"
      return nil
    end

    response.parsed_response
  end

  def call_permission(to_phone_number)
    response = HTTParty.get(
      "#{calls_phone_id_path}/call_permissions",
      headers: calling_api_headers,
      query: { user_wa_id: to_phone_number }
    )
    process_call_permission_response(response)
  rescue Voice::CallErrors::InvalidCallingCredential, Voice::CallErrors::PermissionCheckFailed
    raise
  rescue StandardError => e
    Rails.logger.warn "[WHATSAPP CALL] call_permission transport failure: #{e.class}"
    raise Voice::CallErrors::PermissionCheckFailed, I18n.t('errors.whatsapp.calls.permission_check_failed')
  end

  def initiate_call(to_phone_number, sdp_offer)
    response = HTTParty.post(
      "#{calls_phone_id_path}/calls", headers: calling_api_headers, body: initiate_call_body(to_phone_number, sdp_offer)
    )
    process_initiate_call_response(response)
  end

  # Sets business phone number calling status ('ENABLED'/'DISABLED'). Returns true,
  # or raises with Meta's user-facing message on failure so the caller can surface it.
  def update_calling_status(status)
    response = HTTParty.post(
      "#{calls_phone_id_path}/settings",
      headers: calling_api_headers,
      body: { calling: { status: status } }.to_json
    )
    return confirm_calling_status!(status) if response.success?

    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    error = parsed['error'].is_a?(Hash) ? parsed['error'] : {}
    Rails.logger.error "[WHATSAPP CALL] update_calling_status failed: status=#{response.code} body=#{response.body}"
    raise meta_error_message(error, 'Failed to update calling status')
  end

  private

  def calls_phone_id_path
    base = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    version = GlobalConfigService.load('WHATSAPP_API_VERSION', WHATSAPP_CALLING_API_VERSION_FALLBACK)
    "#{base}/#{version}/#{calling_configuration.phone_number_id}"
  end

  def confirm_calling_status!(expected_status)
    response = HTTParty.get(
      "#{calls_phone_id_path}/settings",
      headers: calling_api_headers,
      query: { fields: 'calling' }
    )
    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    status = parsed.dig('calling', 'status').to_s
    return true if response.success? && status.casecmp?(expected_status.to_s)

    Rails.logger.error(
      "[WHATSAPP CALL] calling status confirmation failed: status=#{response.code} body=#{response.body}"
    )
    error = parsed['error'].is_a?(Hash) ? parsed['error'] : {}
    raise meta_error_message(error, "Meta did not confirm calling status #{expected_status}")
  end

  def calling_api_headers
    { 'Authorization' => "Bearer #{calling_configuration.access_token}", 'Content-Type' => 'application/json' }
  end

  def calling_configuration
    @calling_configuration ||= whatsapp_channel.account.whatsapp_calling_configuration
  end

  def call_action_body(call_id, action, sdp_answer = nil)
    body = { messaging_product: 'whatsapp', call_id: call_id, action: action }
    body[:session] = { sdp: sdp_answer, sdp_type: 'answer' } if sdp_answer
    body
  end

  def call_api(action_name, body)
    url = "#{calls_phone_id_path}/calls"
    Rails.logger.info "[WHATSAPP CALL] #{action_name} POST #{url} body=#{body.except(:session).to_json}"
    response = HTTParty.post(url, headers: calling_api_headers, body: body.to_json)
    Rails.logger.error "[WHATSAPP CALL] #{action_name} failed: status=#{response.code} body=#{response.body}" unless response.success?
    response.success?
  end

  def permission_request_body(to_phone_number, body_text)
    {
      messaging_product: 'whatsapp', recipient_type: 'individual', to: to_phone_number,
      type: 'interactive',
      interactive: {
        type: 'call_permission_request',
        action: { name: 'call_permission_request' },
        body: { text: body_text }
      }
    }.to_json
  end

  def initiate_call_body(to_phone_number, sdp_offer)
    {
      messaging_product: 'whatsapp', to: to_phone_number, action: 'connect',
      session: { sdp: sdp_offer, sdp_type: 'offer' }
    }.to_json
  end

  def process_initiate_call_response(response)
    return response.parsed_response if response.success?

    Rails.logger.error "[WHATSAPP CALL] initiate_call failed: status=#{response.code} body=#{response.body}"
    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    error = parsed['error'].is_a?(Hash) ? parsed['error'] : {}
    error_code = error['code']
    error_msg = meta_error_message(error, 'Failed to initiate call')

    raise Voice::CallErrors::NoCallPermission, error_msg if error_code == Voice::CallErrors::NO_CALL_PERMISSION_CODE

    raise Voice::CallErrors::CallFailed, error_msg
  end

  # The official payload combines a status vocabulary that changed between Graph
  # versions with action capabilities, so both dimensions must be normalized here.
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def process_call_permission_response(response)
    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    unless response.success?
      error = parsed['error'].is_a?(Hash) ? parsed['error'] : {}
      Rails.logger.error "[WHATSAPP CALL] call_permission failed: status=#{response.code} code=#{error['code']}"
      raise Voice::CallErrors::InvalidCallingCredential, I18n.t('errors.whatsapp.calls.invalid_credential') if error['code'].to_i == 190

      raise Voice::CallErrors::PermissionCheckFailed, I18n.t('errors.whatsapp.calls.permission_check_failed')
    end

    permission = parsed['permission'].is_a?(Hash) ? parsed['permission'] : {}
    raw_status = permission['status'].to_s.downcase
    actions = Array(parsed['actions'])
    start_action = actions.find { |action| action['action_name'] == 'start_call' }
    request_action = actions.find { |action| action['action_name'] == 'send_call_permission_request' }
    can_start = start_action ? start_action['can_perform_action'] == true : approved_permission_status?(raw_status)
    can_request = request_action&.dig('can_perform_action') == true

    {
      status: normalized_permission_status(raw_status, can_start),
      permission_status: raw_status.presence || 'unknown',
      can_start_call: can_start,
      can_request_permission: can_request,
      expiration_time: permission['expiration_time'] || permission['expiration']
    }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def approved_permission_status?(status)
    %w[approved granted temporary permanent].include?(status)
  end

  def normalized_permission_status(raw_status, can_start)
    return 'approved' if can_start
    return 'permission_pending' if %w[pending requested].include?(raw_status)
    return 'permission_denied' if %w[denied declined rejected].include?(raw_status)
    return 'permission_expired' if raw_status == 'expired'
    return 'permission_unavailable' if approved_permission_status?(raw_status)

    'permission_required'
  end

  # Meta often returns a blank error_user_msg (e.g. code 131044 business-eligibility);
  # an empty string is truthy, so `||` would surface it. Prefer the first non-blank field.
  def meta_error_message(error, default)
    error['error_user_msg'].presence || error['message'].presence || error['error_user_title'].presence || default
  end
end
# rubocop:enable Metrics/ModuleLength
