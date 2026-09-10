class Sales::DefaultPipelineService
  STAGES = [
    ['Novo Lead', '#3B82F6', 'open'],
    ['Qualificação', '#8B5CF6', 'open'],
    ['Oportunidade', '#F59E0B', 'open'],
    ['Proposta Enviada', '#F97316', 'open'],
    ['Negociação', '#EC4899', 'open'],
    ['Ganho', '#22C55E', 'won'],
    ['Perdido', '#EF4444', 'lost']
  ].freeze
  LOSS_REASONS = ['Preço', 'Sem retorno', 'Escolheu concorrente', 'Sem orçamento', 'Sem interesse', 'Outro'].freeze

  def initialize(account)
    @account = account
  end

  def perform
    ActiveRecord::Base.transaction do
      pipeline = account.sales_pipelines.find_or_create_by!(name: 'Funil Comercial')
      STAGES.each_with_index do |(name, color, stage_type), index|
        pipeline.sales_stages.find_or_create_by!(name: name) do |stage|
          stage.account = account
          stage.position = index + 1
          stage.color = color
          stage.stage_type = stage_type
        end
      end
      LOSS_REASONS.each { |name| account.sales_loss_reasons.find_or_create_by!(name: name) }
      pipeline
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  private

  attr_reader :account
end
