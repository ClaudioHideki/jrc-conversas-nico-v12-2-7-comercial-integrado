require 'rails_helper'

RSpec.describe JrcCrm::DealPolicy do
  Record = Struct.new(:account_id, :owner_id)

  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:account_user) { account.account_users.find_by!(user: agent) }
  let(:context) { { user: agent, account: account, account_user: account_user } }

  it 'allows an agent to update an owned record in the current account' do
    policy = described_class.new(context, Record.new(account.id, agent.id))

    expect(policy.update?).to be(true)
  end

  it 'does not allow an agent to access a record from another account' do
    policy = described_class.new(context, Record.new(other_account.id, agent.id))

    expect(policy.show?).to be(false)
  end

  it 'does not allow an agent to update another owner record' do
    policy = described_class.new(context, Record.new(account.id, create(:user, account: account).id))

    expect(policy.update?).to be(false)
  end
end
