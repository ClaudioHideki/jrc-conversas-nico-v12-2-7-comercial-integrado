module Api
  module V1
    module Accounts
      module Crm
        class RankingController < BaseController
          def index
            ranking_data = JrcCrm::RankingService.new(
              account: crm_scope,
              period: params[:period],
              dimension: params[:dimension] || 'revenue_cents',
              pipeline_id: params[:pipeline_id]
            ).call

            render json: { ranking: ranking_data }
          end
        end
      end
    end
  end
end
