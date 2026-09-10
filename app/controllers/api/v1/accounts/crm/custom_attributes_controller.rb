module Api
  module V1
    module Accounts
      module Crm
        class CustomAttributesController < BaseController
          before_action :set_custom_attribute, only: [:show, :update, :destroy]

          def index
            custom_attributes = crm_scope.custom_attribute_definitions
            custom_attributes = custom_attributes.where(entity_type: params[:entity_type]) if params[:entity_type].present?
            
            render json: custom_attributes
          end

          def show
            render json: @custom_attribute
          end

          def create
            custom_attribute = crm_scope.custom_attribute_definitions.new(custom_attribute_params)
            
            if custom_attribute.save
              render json: custom_attribute, status: :created
            else
              render json: { errors: custom_attribute.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def update
            if @custom_attribute.update(custom_attribute_params)
              render json: @custom_attribute
            else
              render json: { errors: @custom_attribute.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def destroy
            if @custom_attribute.destroy
              head :no_content
            else
              render json: { errors: @custom_attribute.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def set_custom_attribute
            @custom_attribute = crm_scope.custom_attribute_definitions.find(params[:id])
          end

          def custom_attribute_params
            params.require(:custom_attribute_definition).permit(:attribute_display_name, :attribute_key, :attribute_model, :attribute_type, :entity_type)
          end
        end
      end
    end
  end
end
