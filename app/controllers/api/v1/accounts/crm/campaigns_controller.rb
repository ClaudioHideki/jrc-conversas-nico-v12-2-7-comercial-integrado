module Api
  module V1
    module Accounts
      module Crm
        class CampaignsController < BaseController
          before_action :set_campaign, only: [:show, :update, :destroy]

          def index
            campaigns = crm_scope.campaigns
            render json: campaigns
          end

          def show
            render json: @campaign
          end

          def create
            campaign = crm_scope.campaigns.new(campaign_params)
            
            if campaign.save
              render json: campaign, status: :created
            else
              render json: { errors: campaign.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def update
            if @campaign.update(campaign_params)
              render json: @campaign
            else
              render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def destroy
            if @campaign.destroy
              head :no_content
            else
              render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def set_campaign
            @campaign = crm_scope.campaigns.find(params[:id])
          end

          def campaign_params
            params.require(:campaign).permit(:name, :status, :budget_cents, :start_date, :end_date)
          end
        end
      end
    end
  end
end
