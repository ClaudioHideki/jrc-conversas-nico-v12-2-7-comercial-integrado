class JrcNico::OperationalInference
  def self.call(account:, user:, kind:, message:, context:, history: [])
    payload = { request_id: SecureRandom.uuid, account_id: account.id, kind: kind, message: message, context: context, history: history }
    # UTF-8 bytes bound text tokens; allowance covers system prompt, schema, framing and 2,000 output tokens.
    reservation = payload.to_json.bytesize + 12_000
    metered(account: account, user: user, kind: kind, reservation_tokens: reservation) do
      JrcNico::RuntimeClient.new.operate(payload)
    end
  end

  def self.transcribe(account:, user:, upload:)
    raise ArgumentError unless upload.is_a?(ActionDispatch::Http::UploadedFile) && upload.size.between?(16, 4_194_304)

    mime = upload.content_type.to_s.split(';').first
    raise ArgumentError unless %w[audio/webm audio/mp4 audio/ogg audio/wav audio/mpeg].include?(mime)

    audio = upload.read(4_194_305)
    raise ArgumentError if audio.bytesize > 4_194_304

    metered(account: account, user: user, kind: 'transcription') do
      JrcNico::RuntimeClient.new.transcribe(request_id: SecureRandom.uuid, account_id: account.id, mime_type: mime,
                                           audio_base64: Base64.strict_encode64(audio))
    end
  end

  def self.metered(account:, user:, kind:, reservation_tokens: 270_000)
    inference = account.with_lock do
      reservation = JrcNico::RunCapacity.reservation_for!(account, reservation_tokens: reservation_tokens)
      JrcNico::Inference.create!(account: account, user: user, reserved_tokens: reservation)
    end
    result = yield
    account.with_lock do
      if result['mode'] == 'provider'
        JrcAi::UsageEvent.create!(account: account, user: user, agent_key: 'nico', feature: "nico_#{kind}",
                                 model: result.fetch('model'), **result.fetch('usage').symbolize_keys,
                                 metadata: { inference_id: inference.id })
      end
      inference.update!(status: 'completed', reserved_tokens: 0)
    end
    result
  rescue StandardError
    # A failed transport may still have consumed provider tokens; retain the reservation for reconciliation.
    inference&.update!(status: 'unknown') if inference&.status == 'running'
    raise
  end
end
