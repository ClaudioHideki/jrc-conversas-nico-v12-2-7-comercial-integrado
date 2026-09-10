module JrcCrm
  class PipelineSerializer
    def initialize(pipeline)
      @pipeline = pipeline
    end

    def as_json(options = {})
      {
        id: @pipeline.id,
        name: @pipeline.name,
        key: @pipeline.key,
        active: @pipeline.active,
        position: @pipeline.position,
        stages_count: @pipeline.stages.count,
        open_deals_count: @pipeline.deals.where(status: 'open').count,
        pipeline_value_cents: @pipeline.deals.where(status: 'open').sum(:value_cents)
      }
    end
  end
end
