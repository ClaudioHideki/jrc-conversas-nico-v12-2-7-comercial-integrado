require 'rails_helper'

RSpec.describe JrcBrokerIntegration do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:store) { JrcBroker::CredentialStore.new(key: SecureRandom.random_bytes(32)) }
  let(:integration) do
    described_class.create!(account: account, broker_origin: 'https://broker.example.test', organization_id: SecureRandom.uuid,
                           destination_revision: 1, encrypted_control_key: store.encrypt(account_id: account.id, token: 'synthetic-control'))
  end

  it 'never serializes or inspects the stored credential' do
    expect(integration.as_json).to eq('configured' => true, 'has_credential' => true)
    expect(integration.inspect).not_to include(integration.encrypted_control_key)
    expect { integration.dup.save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'rejects a cross-account inbox both in the model and in the database' do
    inbox = create(:channel_api, account: other_account).inbox
    binding = JrcBrokerInboxBinding.new(account: account, inbox: inbox, integration_id: SecureRandom.uuid, instance_id: SecureRandom.uuid)
    expect(binding).not_to be_valid
    integration
    expect do
      JrcBrokerInboxBinding.insert_all!([{ account_id: account.id, inbox_id: inbox.id, integration_id: SecureRandom.uuid,
                                          instance_id: SecureRandom.uuid, created_at: Time.current, updated_at: Time.current }])
    end.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it 'ties delegation to current account and inbox membership and revokes it on removal' do
    integration
    inbox = create(:channel_api, account: account).inbox
    binding = JrcBrokerInboxBinding.create!(account: account, inbox: inbox, integration_id: SecureRandom.uuid, instance_id: SecureRandom.uuid)
    user = create(:user)
    grant = JrcBrokerInboxGrant.new(account: account, inbox: inbox, user: user, can_pair: true)
    expect(grant).not_to be_valid
    create(:account_user, account: account, user: user)
    member = create(:inbox_member, inbox: inbox, user: user)
    grant.save!
    expect(binding.grants.count).to eq(1)
    member.destroy!
    expect(JrcBrokerInboxGrant.where(id: grant.id)).not_to exist
  end
end
