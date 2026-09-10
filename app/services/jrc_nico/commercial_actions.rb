class JrcNico::CommercialActions
  TOOLS = %w[create_deal update_deal update_proposal add_proposal_item].freeze

  def initialize(access)
    @access = access.authorize!
    @account, @user = access.account, access.user
  end

  def call(name, args)
    raise ArgumentError, 'Ação comercial desconhecida.' unless TOOLS.include?(name)

    @args = args
    public_send(name)
  end

  def create_deal
    pipeline = @account.jrc_crm_pipelines.find(@args.fetch('pipeline_id'))
    stage = pipeline.stages.find(@args.fetch('stage_id'))
    contact = @access.contact(@args['contact_id']) if @args['contact_id']
    deal = @account.jrc_crm_deals.create!(@args.slice('title', 'description', 'value_cents').merge(
      pipeline: pipeline, stage: stage, contact: contact, owner: @user, source: 'nico'))
    result(deal, 'Negócio criado', 'crm_deals')
  end

  def update_deal
    deal = @access.crm_scope(JrcCrm::Deal).find(@args.fetch('deal_id'))
    attrs = @args.except('deal_id')
    if attrs['expected_close_at']
      zone = Time.find_zone(@account.reporting_timezone) || Time.zone
      attrs['expected_close_at'] = zone.parse(attrs['expected_close_at'])
      raise ArgumentError, 'Data de fechamento inválida.' unless attrs['expected_close_at']
    end
    deal.update!(attrs)
    result(deal, 'Negócio atualizado', 'crm_deals')
  end

  def update_proposal
    proposal = editable_proposal
    proposal.with_lock do
      ensure_editable!(proposal)
      proposal.update!(@args.except('proposal_id'))
      proposal.reset_approvals!
      proposal.recalculate_totals!
      proposal.events.create!(account_id: @account.id, user: @user, event_type: 'updated', description: 'Proposta atualizada pelo Nico')
    end
    result(proposal.reload, 'Proposta atualizada para revisão; não enviada ao cliente', 'crm_proposals')
  end

  def add_proposal_item
    proposal = editable_proposal
    product = @account.jrc_crm_products.active.find(@args.fetch('product_id'))
    quantity = @args.fetch('quantity')
    # The CRM stores integer quantities. Do not silently truncate model output.
    raise ArgumentError, 'Informe uma quantidade inteira.' unless quantity.to_i == quantity
    raise ArgumentError, "Quantidade mínima do produto: #{product.minimum_quantity}." if quantity < product.minimum_quantity

    proposal.with_lock do
      ensure_editable!(proposal)
      proposal.proposal_items.create!(product: product, quantity: quantity, name_snapshot: product.name,
        description_snapshot: product.description, unit_price_cents: product.unit_price_cents, discount_cents: 0,
        billing_model: product.billing_model, unit_name: product.sales_unit.presence || 'unidade',
        setup_fee_cents: product.setup_fee_cents, included_quantity: product.included_quantity, included_unit: product.included_unit,
        overage_unit_price_cents: product.overage_unit_price_cents, activation_days: product.activation_days,
        validation_period_days: product.validation_period_days)
      proposal.reset_approvals!
    end
    result(proposal.reload, 'Produto incluído com preço e condições do catálogo; proposta não enviada', 'crm_proposals')
  end

  private

  def editable_proposal
    @access.crm_scope(JrcCrm::Proposal).find(@args.fetch('proposal_id'))
  end

  def ensure_editable!(proposal)
    raise ArgumentError, 'A proposta aceita está bloqueada. Duplique-a no CRM para criar outra versão.' if proposal.locked_for_editing?
  end

  def result(record, message, route)
    data = record.attributes.slice('id', 'title', 'status', 'contact_id', 'deal_id', 'value_cents', 'total_cents', 'valid_until')
    if record.is_a?(JrcCrm::Proposal)
      data['items'] = record.proposal_items.map { |item| item.attributes.slice('id', 'product_id', 'name_snapshot', 'quantity', 'unit_price_cents', 'total_cents') }
    end
    { message: "#{message}: #{record.title} (##{record.id})", resource_type: record.class.name, record: data, route_name: route }
  end
end
