module Api
  module V1
    module Accounts
      module Crm
        class LostReasonsController < BaseController
          before_action :set_lost_reason, only: [:show, :update, :destroy]

          def index
            lost_reasons = crm_scope.jrc_crm_lost_reasons
            render json: lost_reasons
          end

          def show
            render json: @lost_reason
          end

          def create
            ensure_crm_admin!
            lost_reason = crm_scope.jrc_crm_lost_reasons.new(lost_reason_params)
            
            if lost_reason.save
              render json: lost_reason, status: :created
            else
              render json: { errors: lost_reason.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def update
            ensure_crm_admin!
            if @lost_reason.update(lost_reason_params)
              render json: @lost_reason
            else
              render json: { errors: @lost_reason.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def destroy
            ensure_crm_admin!
            if @lost_reason.deals.exists?
              render json: { errors: ['Cannot delete lost reason because it is in use by one or more deals'] }, status: :unprocessable_entity
              return
            end

            if @lost_reason.destroy
              head :no_content
            else
              render json: { errors: @lost_reason.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def set_lost_reason
            @lost_reason = crm_scope.jrc_crm_lost_reasons.find(params[:id])
          end

          def lost_reason_params
            params.require(:lost_reason).permit(:name)
          end
        end
      end
    end
  end
end
