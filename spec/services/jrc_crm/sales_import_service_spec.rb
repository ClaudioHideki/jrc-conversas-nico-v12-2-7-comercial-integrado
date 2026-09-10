require 'rails_helper'

RSpec.describe JrcCrm::SalesImportService do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account) }
  let(:contact) { create(:contact, account: account) }

  it 'imports Sales records idempotently while preserving ownership and value' do
    pipeline = SalesPipeline.create!(account: account, name: 'Vendas')
    first_stage = SalesStage.create!(account: account, sales_pipeline: pipeline, name: 'Novo',
                                     position: 1, color: '#2563EB', stage_type: 'open')
    second_stage = SalesStage.create!(account: account, sales_pipeline: pipeline, name: 'Qualificado',
                                      position: 2, color: '#16A34A', stage_type: 'open')
    opportunity = SalesOpportunity.create!(account: account, sales_pipeline: pipeline, sales_stage: second_stage,
                                           contact: contact, owner: owner, title: 'Importada', value: 123.45,
                                           temperature: 'hot', source_channel: 'whatsapp')
    SalesActivity.create!(account: account, sales_opportunity: opportunity, contact: contact, owner: owner,
                          activity_type: 'call', title: 'Retorno', scheduled_at: 1.day.from_now)
    SalesStageHistory.create!(account: account, sales_opportunity: opportunity, from_stage: first_stage,
                              to_stage: second_stage, user: owner, changed_at: Time.current)

    expect { described_class.new(account: account).perform }
      .to change(account.jrc_crm_deals, :count).by(1)
      .and change(account.jrc_crm_activities, :count).by(1)

    imported = account.jrc_crm_deals.find_by!(legacy_sales_opportunity_id: opportunity.id)
    expect(imported.value_cents).to eq(12_345)
    expect(imported.owner).to eq(owner)
    expect(imported.contact).to eq(contact)

    expect { described_class.new(account: account).perform }
      .not_to change(account.jrc_crm_deals, :count)
  end
end
