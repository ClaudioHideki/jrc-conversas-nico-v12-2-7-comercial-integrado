require 'rails_helper'

RSpec.describe JrcAi::CockpitMetricsService do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:membership) { account.account_users.find_by!(user_id: user.id) }
  subject(:metrics) { described_class.new(account: account, user: user, account_user: membership).perform }

  it 'does not invent an analysis timestamp for a configured but unused agent' do
    agent = metrics[:ai_agents].find { |item| item[:key] == 'nico' }
    expect(agent).to include(status: 'not_run', analyzed_at: nil)
    expect(metrics[:summary][:calls_in_progress]).to be_nil
  end

  it 'does not expose CRM counts to an operator without CRM access' do
    account.enable_features!('jrc_crm')
    membership.update!(role: :agent, crm_enabled: false)
    create(:jrc_crm_lead, account: account, owner: user)
    expect(metrics[:summary][:active_leads]).to eq(0)
  end

  it 'marks unknown provider cost unavailable instead of free' do
    JrcAi::UsageEvent.create!(account: account, user: user, model: 'test', total_tokens: 50, input_tokens: 40, output_tokens: 10,
                             metadata: { cost_available: false })
    expect(metrics[:usage][:estimated_cost_cents_month]).to be_nil
  end
end
