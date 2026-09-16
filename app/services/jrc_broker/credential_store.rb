class JrcBroker::CredentialStore
  class InvalidCredential < StandardError; end

  def initialize(key:)
    raise InvalidCredential, 'JRC_BROKER_CREDENTIAL_UNAVAILABLE' unless key.is_a?(String) && key.bytesize == 32

    @encryptor = ActiveSupport::MessageEncryptor.new(key, cipher: 'aes-256-gcm', serializer: JSON)
  end

  def encrypt(account_id:, token:)
    raise InvalidCredential, 'JRC_BROKER_CREDENTIAL_UNAVAILABLE' unless token.is_a?(String) && token.present? && token.bytesize <= 4096

    @encryptor.encrypt_and_sign(token, purpose: "jrc-broker:account:#{account_id}")
  end

  def decrypt(account_id:, ciphertext:)
    value = @encryptor.decrypt_and_verify(ciphertext, purpose: "jrc-broker:account:#{account_id}")
    raise InvalidCredential, 'JRC_BROKER_CREDENTIAL_UNAVAILABLE' unless value.is_a?(String) && value.present?

    value
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError
    raise InvalidCredential, 'JRC_BROKER_CREDENTIAL_UNAVAILABLE'
  end
end
