module JrcCrm
  class DefaultPipelineService
    STAGES = [
      ['Novo Lead', 'new_lead', '#60A5FA', 10, false, false],
      ['Qualificação', 'qualification', '#818CF8', 25, false, false],
      ['Oportunidade', 'opportunity', '#A78BFA', 40, false, false],
      ['Proposta Enviada', 'proposal_sent', '#F59E0B', 60, false, false],
      ['Negociação', 'negotiation', '#F97316', 80, false, false],
      ['Ganho', 'won', '#22C55E', 100, true, false],
      ['Perdido', 'lost', '#EF4444', 0, false, true]
    ].freeze

    LOST_REASONS = ['Preço', 'Sem retorno', 'Concorrência', 'Sem interesse', 'Outro'].freeze

    def initialize(account)
      @account = account
    end

    def perform
      pipeline = @account.jrc_crm_pipelines.find_or_create_by!(key: 'default') do |record|
        record.name = 'Funil Comercial'
        record.position = 1
        record.active = true
      end

      STAGES.each_with_index do |(name, key, color, probability, won, lost), index|
        @account.jrc_crm_stages.find_or_create_by!(pipeline: pipeline, key: key) do |stage|
          stage.name = name
          stage.position = index + 1
          stage.color = color
          stage.probability = probability
          stage.is_terminal = won || lost
          stage.is_won = won
          stage.is_lost = lost
          stage.active = true
        end
      end

      LOST_REASONS.each do |name|
        @account.jrc_crm_lost_reasons.find_or_create_by!(name: name) { |reason| reason.active = true }
      end

      pipeline.reload
    end
  end
end
