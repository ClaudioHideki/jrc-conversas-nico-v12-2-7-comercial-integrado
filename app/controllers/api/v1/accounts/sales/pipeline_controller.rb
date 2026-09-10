class Api::V1::Accounts::Sales::PipelineController < Api::V1::Accounts::Sales::BaseController
  def show
    pipeline = Sales::DefaultPipelineService.new(Current.account).perform
    render json: {
      id: pipeline.id,
      name: pipeline.name,
      stages: pipeline.sales_stages.where(active: true).map { |stage| serialize_stage(stage) },
      loss_reasons: Current.account.sales_loss_reasons.where(active: true).order(:name).map { |reason| { id: reason.id, name: reason.name } }
    }
  end
end
