require 'rails_helper'

RSpec.describe JrcCrm::Deal, type: :model do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account) }
  let(:pipeline) { JrcCrm::Pipeline.create!(account: account, name: 'Principal', key: 'principal', position: 1) }
  let(:stage) do
    JrcCrm::Stage.create!(account: account, pipeline: pipeline, name: 'Novo', key: 'novo', position: 1)
  end

  it 'rejects associations from another account' do
    foreign_contact = create(:contact, account: create(:account))
    deal = described_class.new(account: account, pipeline: pipeline, stage: stage, owner: owner,
                               contact: foreign_contact, title: 'Teste', value_cents: 0)

    expect(deal).not_to be_valid
    expect(deal.errors[:contact]).to be_present
  end

  it 'requires a loss reason or note when status is lost' do
    deal = described_class.new(account: account, pipeline: pipeline, stage: stage, owner: owner,
                               title: 'Teste', value_cents: 0, status: 'lost')

    expect(deal).not_to be_valid
    expect(deal.errors[:base]).to be_present
  end

  it 'returns only the nearest pending future activity when activities are preloaded' do
    deal = described_class.create!(account: account, pipeline: pipeline, stage: stage, owner: owner,
                                   title: 'Teste', value_cents: 0)
    JrcCrm::Activity.create!(account: account, user: owner, deal: deal, activity_type: 'task',
                             title: 'Passada', due_at: 1.hour.ago)
    JrcCrm::Activity.create!(account: account, user: owner, deal: deal, activity_type: 'task',
                             title: 'Concluída', due_at: 1.hour.from_now, status: 'completed')
    expected = JrcCrm::Activity.create!(account: account, user: owner, deal: deal, activity_type: 'follow_up',
                                       title: 'Próxima', due_at: 2.hours.from_now)
    JrcCrm::Activity.create!(account: account, user: owner, deal: deal, activity_type: 'task',
                             title: 'Posterior', due_at: 3.hours.from_now)

    deal = described_class.includes(:activities).find(deal.id)

    expect(deal.next_activity).to eq(expected)
  end
end
