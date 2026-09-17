class JrcFlows::Secrets
  def self.box
    key = Rails.application.key_generator.generate_key('jrc-flows-integration-v1', 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: 'aes-256-gcm', serializer: JSON)
  end

  def self.encrypt(value)
    box.encrypt_and_sign(value.to_json)
  end

  def self.decrypt(value)
    value.present? ? JSON.parse(box.decrypt_and_verify(value)) : {}
  end
end
