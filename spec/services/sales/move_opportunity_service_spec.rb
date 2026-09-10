require 'rails_helper'

RSpec.describe Sales::MoveOpportunityService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:pipeline) { Sales::DefaultPipelineService.new(account).perform }
  let(:opportunity) do
    create(
      :sales_opportunity,
      account: account,
      sales_pipeline: pipeline,
      sales_stage: pipeline.sales_stages.find_by!(position: 1),
      owner: user
    )
  end

  it 'moves an opportunity and records the responsible user and timestamp' do
    target_stage = pipeline.sales_stages.find_by!(position: 2)

    described_class.new(opportunity: opportunity, stage: target_stage, user: user).perform

    history = opportunity.sales_stage_histories.last
    expect(opportunity.reload.sales_stage).to eq(target_stage)
    expect(history).to have_attributes(from_stage_id: pipeline.sales_stages.find_by!(position: 1).id, to_stage_id: target_stage.id,
                                       user_id: user.id)
    expect(history.changed_at).to be_present
  end

  it 'requires a reason before marking an opportunity as lost' do
    lost_stage = pipeline.sales_stages.find_by!(stage_type: 'lost')

    expect do
      described_class.new(opportunity: opportunity, stage: lost_stage, user: user).perform
    end.to raise_error(ActiveRecord::RecordInvalid, /Loss reason/)
  end

  it 'does not allow a stage from another account' do
    other_account = create(:account)
    other_stage = Sales::DefaultPipelineService.new(other_account).perform.sales_stages.first

    expect do
      described_class.new(opportunity: opportunity, stage: other_stage, user: user).perform
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
