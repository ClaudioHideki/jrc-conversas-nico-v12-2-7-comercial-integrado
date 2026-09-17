class JrcFlowConnection < ApplicationRecord
  belongs_to :account
  has_many :flows, class_name: 'JrcFlow', foreign_key: :connection_id, dependent: :restrict_with_error
  has_many :remote_sessions, class_name: 'JrcFlowRemoteSession', foreign_key: :connection_id
  has_many :remote_events, class_name: 'JrcFlowRemoteEvent', foreign_key: :connection_id
  before_validation { self.public_id ||= SecureRandom.uuid }
  before_validation { self.base_url = base_url.to_s.strip.delete_suffix('/') }
  validates :name, presence: true, length: { maximum: 120 }
  validates :public_id, uniqueness: true
  validates :remote_account_id, numericality: { only_integer: true, greater_than: 0 }
  validates :credential_ciphertext, length: { maximum: 100_000 }, allow_nil: true
  validates :base_url, uniqueness: { scope: [:account_id, :remote_account_id] }
  validate :validate_origin
  validate do
    errors.add(:inbox_ids, 'inválidas') unless inbox_ids.is_a?(Array) && inbox_ids.all? { |id| id.is_a?(Integer) && id.positive? }
  end

  def secrets
    JrcFlows::Secrets.decrypt(credential_ciphertext)
  end

  def secrets=(value)
    allowed = %w[api_token bot_token webhook_secret openai_api_key http_api_key]
    raise ArgumentError, 'Credenciais inválidas.' unless value.is_a?(Hash) && (value.keys - allowed).empty? &&
      value.values.all? { |v| v.is_a?(String) && v.bytesize <= 8192 && !v.match?(/[\r\n]/) }

    self.credential_ciphertext = JrcFlows::Secrets.encrypt(secrets.merge(value.reject { |_, v| v.blank? }))
  end

  def portal_url
    "#{ENV.fetch('FRONTEND_URL').delete_suffix('/')}/flows/portal/#{public_id}"
  end

  def webhook_url
    base = ENV.fetch('JRC_FLOWS_WEBHOOK_BASE_URL', ENV.fetch('FRONTEND_URL')).delete_suffix('/')
    "#{base}/jrc_flows/events/#{public_id}"
  end

  def snapshot
    as_json(only: %i[id public_id name base_url remote_account_id bot_id dashboard_app_id enabled inbox_ids catalog verified_at]).merge(
      'account_id' => account_id, 'portal_url' => portal_url, 'webhook_url' => webhook_url,
      'credential_configured' => secrets.keys
    )
  end

  private

  def validate_origin
    uri = URI.parse(base_url)
    valid = uri.is_a?(URI::HTTPS) && uri.host.present?
    # Exact deployment-owned origins are used only for local homologation.
    valid ||= ENV.fetch('JRC_FLOWS_LOCAL_ORIGIN_MAP', '{}').then { |v| JSON.parse(v).key?(base_url) }
    valid &&= uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil? && ['', '/'].include?(uri.path)
    errors.add(:base_url, 'informe a origem HTTPS do Chatwoot, sem caminho ou credenciais') unless valid
  rescue URI::InvalidURIError, JSON::ParserError
    errors.add(:base_url, 'inválida')
  end
end
