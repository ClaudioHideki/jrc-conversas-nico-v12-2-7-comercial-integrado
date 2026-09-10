require 'rails_helper'

RSpec.describe JrcCrm::ConversationLeadService do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, :with_team, account: account) }

  it 'creates a lead connected to the conversation context' do
    result = described_class.new(account: account, conversation: conversation, actor: agent).call
    lead = result[:lead]

    expect(result[:created]).to be(true)
    expect(lead).to have_attributes(
      account_id: account.id,
      owner_id: agent.id,
      contact_id: conversation.contact_id,
      conversation_id: conversation.id,
      team_id: conversation.team_id,
      classified_at: be_present
    )
    expect(lead.idempotency_key).to eq("conversation:#{conversation.id}")
    expect(lead.source).to eq('web_widget')
  end

  it 'returns the same lead when the action is repeated' do
    first = described_class.new(account: account, conversation: conversation, actor: agent).call
    second = described_class.new(account: account, conversation: conversation, actor: agent).call

    expect(second[:created]).to be(false)
    expect(second[:lead].id).to eq(first[:lead].id)
    expect(account.jrc_crm_leads.where(conversation_id: conversation.id).count).to eq(1)
  end
end
