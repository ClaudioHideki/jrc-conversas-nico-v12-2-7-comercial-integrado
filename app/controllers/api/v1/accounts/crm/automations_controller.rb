module Api
  module V1
    module Accounts
      module Crm
        class AutomationsController < BaseController
          before_action :set_automation, only: [:show, :update, :destroy, :toggle_active]

          def index
            automations = crm_scope.automation_rules
            render json: automations
          end

          def show
            render json: @automation
          end

          def create
            automation = crm_scope.automation_rules.new(automation_params)
            
            if automation.save
              render json: automation, status: :created
            else
              render json: { errors: automation.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def update
            if @automation.update(automation_params)
              render json: @automation
            else
              render json: { errors: @automation.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def destroy
            if @automation.destroy
              head :no_content
            else
              render json: { errors: @automation.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def toggle_active
            if @automation.update(active: !@automation.active)
              render json: @automation
            else
              render json: { errors: @automation.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def set_automation
            @automation = crm_scope.automation_rules.find(params[:id])
          end

          def automation_params
            params.require(:automation_rule).permit(:name, :description, :trigger_type, :active, conditions: [], actions: [])
          end
        end
      end
    end
  end
end
