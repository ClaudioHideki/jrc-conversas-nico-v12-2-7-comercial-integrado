require 'rails_helper'

RSpec.describe Sales::DefaultPipelineService do
  let(:account) { create(:account) }

  it 'creates the default pipeline, stages, and loss reasons idempotently' do
    2.times { described_class.new(account).perform }

    expect(account.sales_pipelines.count).to eq(1)
    expect(account.sales_stages.order(:position).pluck(:name)).to eq(
      ['Novo Lead', 'Qualificação', 'Oportunidade', 'Proposta Enviada', 'Negociação', 'Ganho', 'Perdido']
    )
    expect(account.sales_loss_reasons.count).to eq(6)
  end
end
