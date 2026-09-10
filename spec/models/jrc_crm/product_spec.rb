require 'rails_helper'

RSpec.describe JrcCrm::Product, type: :model do
  let(:account) { create(:account) }

  it 'calcula a equivalência mensal para cobranças mensais, anuais e por uso' do
    monthly = described_class.new(account: account, name: 'Mensal', billing_model: 'monthly', unit_price_cents: 1_200_00)
    annual = described_class.new(account: account, name: 'Anual', billing_model: 'annual', unit_price_cents: 12_000_00)
    usage = described_class.new(account: account, name: 'Uso', billing_model: 'usage', unit_price_cents: 450_00)

    expect(monthly.monthly_equivalent_cents).to eq(1_200_00)
    expect(annual.monthly_equivalent_cents).to eq(1_000_00)
    expect(usage.monthly_equivalent_cents).to eq(450_00)
  end

  it 'impede preço de venda abaixo do preço mínimo' do
    product = described_class.new(
      account: account,
      name: 'STIR/SHAKEN',
      unit_price_cents: 2_000_00,
      minimum_price_cents: 2_500_00
    )

    expect(product).not_to be_valid
    expect(product.errors[:unit_price_cents]).to include('não pode ser menor que o preço mínimo')
  end

  it 'mantém somente integrações internas aprovadas para esta versão' do
    product = described_class.new(
      account: account,
      name: 'JRC Conversas',
      integrations: %w[financial contracts implementation external_connector]
    )

    product.valid?

    expect(product.integrations).to contain_exactly('financial', 'contracts', 'implementation')
  end
end
