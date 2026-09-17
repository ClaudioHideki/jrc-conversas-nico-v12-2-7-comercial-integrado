# == Schema Information
#
# Table name: jrc_flows
#
#  id                    :bigint           not null, primary key
#  credential_ciphertext :text
#  description           :text
#  engine                :string           default("native"), not null
#  graph                 :jsonb            not null
#  kind                  :string           default("chatbot"), not null
#  lock_version          :integer          default(0), not null
#  name                  :string           not null
#  next_run_at           :datetime
#  settings              :jsonb            not null
#  source_ciphertext     :text
#  status                :string           default("draft"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  created_by_id         :bigint
#
# Indexes
#
#  index_jrc_flows_on_account_id             (account_id)
#  index_jrc_flows_on_account_id_and_status  (account_id,status)
#  index_jrc_flows_on_created_by_id          (created_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id) ON DELETE => nullify
#
class JrcFlow < ApplicationRecord
  belongs_to :account
  belongs_to :connection, class_name: 'JrcFlowConnection', optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :runs, class_name: 'JrcFlowRun', foreign_key: :flow_id, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :kind, inclusion: { in: %w[chatbot workflow sequence voice] }
  validates :status, inclusion: { in: %w[draft active paused] }
  validates :engine, inclusion: { in: %w[native workflow] }
  validates :source_ciphertext, length: { maximum: 6.megabytes }, allow_nil: true
  validates :credential_ciphertext, length: { maximum: 50_000 }, allow_nil: true
  validate :validate_definition

  scope :active, -> { where(status: 'active') }

  def validate_definition
    validator = connection_id ? JrcFlows::RemoteDefinition : JrcFlows::Definition
    validator.new(self).errors(complete: status == 'active').each { |error| errors.add(:base, error) }
    errors.add(:connection, 'deve pertencer à conta') if connection && connection.account_id != account_id
  end

  def snapshot
    as_json(only: %i[id name description kind status engine graph settings lock_version created_at updated_at connection_id]).merge(
      'external' => external_summary, 'workflow' => source_definition,
      'credential_configured' => effective_secrets.keys
    )
  end

  def source_definition
    JSON.parse(secret_box.decrypt_and_verify(source_ciphertext)) if source_ciphertext.present?
  end

  def source_definition=(value)
    self.source_ciphertext = value.nil? ? nil : secret_box.encrypt_and_sign(value.to_json)
  end

  def connection_secrets
    credential_ciphertext.present? ? JSON.parse(secret_box.decrypt_and_verify(credential_ciphertext)) : {}
  end

  def effective_secrets
    inherited = connection ? connection.secrets.slice('openai_api_key', 'http_api_key') : {}
    inherited.merge(connection_secrets)
  end

  def sibling_flows
    account.jrc_flows.where(connection_id: connection_id)
  end

  def execution_team_ids
    connection ? connection.catalog.fetch('teams', []).pluck('id') : account.teams.ids
  end

  def connection_secrets=(value)
    raise JrcFlows::Importer::Invalid, 'Credenciais inválidas.' unless value.is_a?(Hash) && value.values.all? { |v| v.is_a?(String) && v.bytesize <= 8192 && !v.match?(/[\r\n]/) }
    merged = connection_secrets.merge(value.reject { |_, v| v.blank? })
    self.credential_ciphertext = secret_box.encrypt_and_sign(merged.to_json)
  end

  def workflow_json=(value)
    attributes = JrcFlows::Importer.new(value).attributes
    raise JrcFlows::Importer::Invalid, 'Esperado um workflow com nodes e connections.' unless attributes['source_definition']

    self.source_definition = attributes['source_definition']
  end

  def external_summary
    JrcFlows::Importer.summary(source_definition) if engine == 'workflow' && source_ciphertext.present?
  end

  def export_definition
    data = snapshot.slice('name', 'description', 'kind', 'graph', 'settings', 'engine')
    { format: engine == 'workflow' ? 'jrc-flows/2' : 'jrc-flows/1', flow: data }.tap do |result|
      result[:workflow] = source_definition if engine == 'workflow'
    end
  end

  private

  def secret_box
    key = Rails.application.key_generator.generate_key('jrc-flows-integration-v1', 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: 'aes-256-gcm', serializer: JSON)
  end
end
