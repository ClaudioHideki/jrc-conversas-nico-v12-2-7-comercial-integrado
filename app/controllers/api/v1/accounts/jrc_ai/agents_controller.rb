module Api
  module V1
    module Accounts
      module JrcAi
        class AgentsController < BaseController
          def index
            result = ::JrcAi::CockpitMetricsService.new(
              account: Current.account,
              user: Current.user,
              account_user: Current.account_user,
              period: params[:period]
            ).perform

            render json: {
              agents: result[:ai_agents],
              attention: result[:attention],
              generated_at: result[:generated_at],
              profile: result[:profile]
            }
          end
        end
      end
    end
  end
end
