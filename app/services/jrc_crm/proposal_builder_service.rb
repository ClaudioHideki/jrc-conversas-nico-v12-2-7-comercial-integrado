module JrcCrm
  class ProposalBuilderService
    DEFAULT_COMMERCIAL_NOTES = <<~TEXT.strip.freeze
      Valores em reais. Condições sujeitas a validação comercial e técnica.
      Consumos variáveis, excedentes, APIs, mensagens e serviços não descritos nos itens serão faturados conforme utilização e contratação aplicável.
    TEXT

    DEFAULT_NEXT_STEPS = <<~TEXT.strip.freeze
      1. Aprovação do escopo e das condições comerciais
      2. Alinhamento técnico e confirmação dos dados de implantação
      3. Configuração, testes e homologação
      4. Go-live e acompanhamento inicial da operação
    TEXT

    def initialize(deal:, actor:)
      @deal = deal
      @actor = actor
      @account = deal.account
    end

    def call
      ActiveRecord::Base.transaction do
        proposal = JrcCrm::Proposal.create!(
          account_id: @account.id,
          deal_id: @deal.id,
          owner_id: @actor.id,
          title: "Proposta - #{@deal.title}",
          status: 'draft',
          solution_description: @deal.description.presence || default_solution_description,
          implementation_cents: 0,
          monthly_cents: 0,
          valid_until: 15.days.from_now.to_date,
          term_months: 12,
          commercial_notes: DEFAULT_COMMERCIAL_NOTES,
          next_steps: DEFAULT_NEXT_STEPS,
          approval_status: 'not_required',
          commercial_approval_status: 'not_required',
          financial_approval_status: 'not_required',
          technical_approval_status: 'not_required'
        )

        @deal.deal_products.includes(:product).find_each do |deal_product|
          create_item_from_deal_product!(proposal, deal_product)
        end

        proposal.reload
        proposal.recalculate_totals!

        JrcCrm::ProposalEvent.create!(
          account_id: @account.id,
          proposal_id: proposal.id,
          event_type: 'created',
          user_id: @actor.id,
          description: 'Proposta criada a partir do negócio'
        )

        proposal.reload
      end
    end

    private

    def create_item_from_deal_product!(proposal, deal_product)
      product = deal_product.product
      JrcCrm::ProposalItem.create!(
        proposal_id: proposal.id,
        product_id: product&.id,
        name_snapshot: product&.name || deal_product.description_snapshot.presence || 'Item sem nome',
        description_snapshot: deal_product.description_snapshot.presence || product&.description,
        unit_price_cents: deal_product.unit_price_cents || product&.unit_price_cents || 0,
        quantity: deal_product.quantity || 1,
        discount_cents: deal_product.discount_cents || 0,
        billing_model: product&.billing_model || 'one_time',
        unit_name: product&.sales_unit.presence || 'unidade',
        setup_fee_cents: product&.setup_fee_cents.to_i,
        included_quantity: product&.included_quantity.to_f,
        included_unit: product&.included_unit,
        overage_unit_price_cents: product&.overage_unit_price_cents.to_i,
        activation_days: product&.activation_days.to_i,
        validation_period_days: product&.validation_period_days.to_i
      )
    end

    def default_solution_description
      customer_name = @deal.contact&.name.presence || @deal.title
      "Solução comercial JRC preparada para #{customer_name}, reunindo atendimento, relacionamento e operação em um único fluxo."
    end
  end
end
