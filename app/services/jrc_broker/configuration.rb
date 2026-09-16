class JrcBroker::Configuration
  class InvalidConfiguration < StandardError; end

  def self.enabled?
    ENV['JRC_BROKER_ENABLED'] == 'true'
  end

  def self.credential_store
    JrcBroker::CredentialStore.new(key: Base64.strict_decode64(ENV.fetch('JRC_BROKER_CREDENTIAL_KEY', '')))
  rescue ArgumentError
    raise JrcBroker::CredentialStore::InvalidCredential, 'JRC_BROKER_CREDENTIAL_UNAVAILABLE'
  end

  def self.allowed_origin!(value)
    origin = canonical_origin!(value)
    allowed = ENV.fetch('JRC_BROKER_ALLOWED_ORIGINS', '').split(',').map(&:strip)
    raise InvalidConfiguration, 'JRC_BROKER_ORIGIN_NOT_ALLOWED' unless allowed.include?(origin)

    origin
  end

  def self.canonical_origin!(value)
    uri = URI.parse(value.to_s)
    # Exact equality also rejects userinfo, paths, query strings, fragments and explicit ports.
    valid = uri.is_a?(URI::HTTPS) && uri.host.present? && uri.port == 443
    raise InvalidConfiguration, 'JRC_BROKER_INVALID_ORIGIN' unless valid && value == "https://#{uri.host}"

    value
  rescue URI::InvalidURIError
    raise InvalidConfiguration, 'JRC_BROKER_INVALID_ORIGIN'
  end

  def self.configure!(account:, origin:, organization_id:, token:, client:)
    raise InvalidConfiguration, 'JRC_BROKER_DISABLED' unless enabled?

    origin = allowed_origin!(origin)
    context = client.context
    validate_context!(context, account.id, organization_id)
    ciphertext = credential_store.encrypt(account_id: account.id, token: token)
    # The Broker calls back into Rails during onboarding; never hold a lock during HTTP.
    account.with_lock do
      record = JrcBrokerIntegration.find_or_initialize_by(account: account)
      if record.persisted? && (record.broker_origin != origin || record.organization_id != organization_id)
        raise InvalidConfiguration, 'JRC_BROKER_ALREADY_BOUND'
      end

      record.update!(broker_origin: origin, organization_id: organization_id, encrypted_control_key: ciphertext,
                     destination_revision: context.fetch('destinationRevision'))
      record
    end
  end

  def self.validate_context!(context, account_id, organization_id)
    valid = context.is_a?(Hash) && context['accountId'] == account_id && context['organizationId'] == organization_id &&
            context['chatwootOrigin'] == canonical_origin!(ENV.fetch('FRONTEND_URL', '')) &&
            context['destinationRevision'].is_a?(Integer) && context['destinationRevision'].positive?
    raise InvalidConfiguration, 'JRC_BROKER_CONTEXT_MISMATCH' unless valid
  end
end
