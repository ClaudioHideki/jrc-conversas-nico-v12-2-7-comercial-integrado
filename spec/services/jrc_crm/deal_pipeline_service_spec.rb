require 'rails_helper'

RSpec.describe JrcCrm::DealPipelineService do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account) }
  let(:pipeline) { JrcCrm::Pipeline.create!(account: account, name: 'Principal', key: 'principal', position: 1) }
  let(:first_stage) do
    JrcCrm::Stage.create!(account: account, pipeline: pipeline, name: 'Novo', key: 'novo', position: 1)
  end
  let(:won_stage) do
    JrcCrm::Stage.create!(account: account, pipeline: pipeline, name: 'Ganho', key: 'ganho', position: 2,
                         is_terminal: true, is_won: true)
  end
  let(:deal) do
    JrcCrm::Deal.create!(account: account, pipeline: pipeline, stage: first_stage, owner: owner,
                        title: 'Venda', value_cents: 10_000)
  end

  it 'moves the deal, marks it as won and records an audit event' do
    result = described_class.new(deal: deal, stage: won_stage, actor: owner).call

    expect(result[:success]).to be(true)
    expect(deal.reload).to be_won
    expect(account.jrc_crm_audit_events.where(event_type: 'deal_stage_changed', resource_id: deal.id)).to exist
  end

  it 'rejects a stage belonging to another account' do
    foreign_account = create(:account)
    foreign_pipeline = JrcCrm::Pipeline.create!(account: foreign_account, name: 'Outro', key: 'outro', position: 1)
    foreign_stage = JrcCrm::Stage.create!(account: foreign_account, pipeline: foreign_pipeline,
                                         name: 'Outro', key: 'outro', position: 1)

    result = described_class.new(deal: deal, stage: foreign_stage, actor: owner).call

    expect(result[:success]).to be(false)
    expect(deal.reload.stage).to eq(first_stage)
  end
end
