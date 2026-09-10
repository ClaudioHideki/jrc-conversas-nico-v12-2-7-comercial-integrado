module Api
  module V1
    module Accounts
      module Crm
        class PipelinesController < BaseController
          before_action :set_pipeline, only: [:show, :update, :destroy]

          def index
            JrcCrm::DefaultPipelineService.new(crm_scope).perform unless crm_scope.jrc_crm_pipelines.exists?
            pipelines = crm_scope.jrc_crm_pipelines.order(:position)
            render json: pipelines.map { |pipeline| JrcCrm::PipelineSerializer.new(pipeline).as_json }
          end

          def show
            render json: JrcCrm::PipelineSerializer.new(@pipeline).as_json
          end

          def create
            ensure_crm_admin!
            pipeline = crm_scope.jrc_crm_pipelines.new(pipeline_params)
            
            if pipeline.save
              render json: JrcCrm::PipelineSerializer.new(pipeline).as_json, status: :created
            else
              render json: { errors: pipeline.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def update
            ensure_crm_admin!
            if @pipeline.update(pipeline_params)
              render json: JrcCrm::PipelineSerializer.new(@pipeline).as_json
            else
              render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def destroy
            ensure_crm_admin!
            if @pipeline.destroy
              head :no_content
            else
              render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def set_pipeline
            @pipeline = crm_scope.jrc_crm_pipelines.find(params[:id])
          end

          def pipeline_params
            params.require(:pipeline).permit(:name, :key, :active, :position)
          end
        end
      end
    end
  end
end
