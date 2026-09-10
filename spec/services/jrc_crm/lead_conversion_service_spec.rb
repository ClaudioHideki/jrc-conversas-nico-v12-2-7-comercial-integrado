require 'rails_helper'

RSpec.describe JrcCrm::LeadConversionService do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account) }
  let(:lead) do
    JrcCrm::Lead.create!(account: account, owner: owner, name: 'Cliente potencial',
                        email: 'crm-lead@example.test', source: 'manual', status: 'qualified')
  end

  it 'creates a contact and deal atomically and marks the lead converted' do
    result = described_class.new(lead: lead, account: account, actor: owner, params: {}).call

    expect(result[:success]).to be(true)
    expect(result[:contact]).to be_persisted
    expect(result[:deal]).to be_persisted
    expect(lead.reload.status).to eq('converted')
    expect(result[:deal].contact).to eq(result[:contact])
    expect(result[:deal].conversion_key).to eq("lead:#{lead.id}")
    expect(JrcCrm::AuditEvent.for_resource('JrcCrm::Lead', lead.id).where(event_type: 'lead_converted')).to exist
  end

  it 'returns the same deal when conversion is requested twice' do
    first = described_class.new(lead: lead, account: account, actor: owner, params: {}).call
    second = described_class.new(lead: lead.reload, account: account, actor: owner, params: {}).call

    expect(second[:success]).to be(true)
    expect(second[:created]).to be(false)
    expect(second[:deal].id).to eq(first[:deal].id)
    expect(account.jrc_crm_deals.where(lead_id: lead.id).count).to eq(1)
  end

  it 'rejects a lead that has not been qualified' do
    lead.update!(status: 'in_contact')

    result = described_class.new(lead: lead, account: account, actor: owner, params: {}).call

    expect(result[:success]).to be(false)
    expect(account.jrc_crm_deals.where(lead_id: lead.id)).to be_empty
  end

  it 'does not allow a pipeline from another account' do
    foreign_account = create(:account)
    foreign_pipeline = JrcCrm::Pipeline.create!(account: foreign_account, name: 'Externo', key: 'externo', position: 1)

    result = described_class.new(lead: lead, account: account, actor: owner,
                                 params: { pipeline_id: foreign_pipeline.id }).call

    expect(result[:success]).to be(false)
    expect(lead.reload.status).to eq('qualified')
  end
end
