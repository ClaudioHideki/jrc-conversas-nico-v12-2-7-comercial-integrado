FactoryBot.define do
  factory :jrc_crm_pipeline, class: 'JrcCrm::Pipeline' do
    association :account
    name { 'Novas Vendas' }
    key { 'novas_vendas' }
    position { 1 }
    active { true }
    settings { {} }
  end

  factory :jrc_crm_stage, class: 'JrcCrm::Stage' do
    association :account
    association :pipeline, factory: :jrc_crm_pipeline
    sequence(:name) { |n| "Etapa #{n}" }
    sequence(:key) { |n| "etapa_#{n}" }
    sequence(:position) { |n| n }
    color { '#6366F1' }
    probability { 50.0 }
    active { true }
    is_terminal { false }
    is_won { false }
    is_lost { false }
  end

  factory :jrc_crm_won_stage, parent: :jrc_crm_stage do
    name { 'Fechado / Ganho' }
    key { 'won' }
    is_terminal { true }
    is_won { true }
    probability { 100.0 }
  end

  factory :jrc_crm_lost_stage, parent: :jrc_crm_stage do
    name { 'Perdido' }
    key { 'lost' }
    is_terminal { true }
    is_lost { true }
    probability { 0.0 }
  end

  factory :jrc_crm_lost_reason, class: 'JrcCrm::LostReason' do
    association :account
    name { 'Preço' }
    active { true }
  end

  factory :jrc_crm_lead, class: 'JrcCrm::Lead' do
    association :account
    association :owner, factory: :user
    name { 'Empresa Exemplo Ltda' }
    company_name { 'Empresa Exemplo Ltda' }
    email { 'contato@exemplo.test' }
    phone { '11999990000' }
    source { 'manual' }
    status { 'new' }
    score { 50 }
    notes { 'Lead de teste' }
    custom_attributes { {} }
  end

  factory :jrc_crm_deal, class: 'JrcCrm::Deal' do
    association :account
    association :pipeline, factory: :jrc_crm_pipeline
    association :stage, factory: :jrc_crm_stage
    association :owner, factory: :user
    title { 'Negócio Exemplo' }
    value_cents { 5000_00 }
    currency { 'BRL' }
    status { 'open' }
    probability { 50.0 }
  end

  factory :jrc_crm_product, class: 'JrcCrm::Product' do
    association :account
    name { 'Produto Exemplo' }
    sku { 'PROD-001' }
    category { 'Software' }
    unit_price_cents { 1000_00 }
    currency { 'BRL' }
    active { true }
  end

  factory :jrc_crm_proposal, class: 'JrcCrm::Proposal' do
    association :account
    association :deal, factory: :jrc_crm_deal
    association :owner, factory: :user
    title { 'Proposta Exemplo' }
    status { 'draft' }
    subtotal_cents { 1000_00 }
    discount_cents { 0 }
    total_cents { 1000_00 }
  end

  factory :jrc_crm_activity, class: 'JrcCrm::Activity' do
    association :account
    association :user
    association :deal, factory: :jrc_crm_deal
    activity_type { 'call' }
    title { 'Ligação de seguimento' }
    due_at { 1.day.from_now }
  end

  factory :jrc_crm_automation_rule, class: 'JrcCrm::AutomationRule' do
    association :account
    name { 'Regra Teste' }
    trigger_type { 'deal_created' }
    conditions { [] }
    actions { [{ type: 'send_internal_notification', params: { message: 'Novo negócio criado' } }] }
    active { true }
  end

  factory :jrc_crm_import_batch, class: 'JrcCrm::ImportBatch' do
    association :account
    association :user
    file_name { 'leads.csv' }
    import_type { 'leads' }
    row_count { 10 }
    status { 'pending' }
  end
end
