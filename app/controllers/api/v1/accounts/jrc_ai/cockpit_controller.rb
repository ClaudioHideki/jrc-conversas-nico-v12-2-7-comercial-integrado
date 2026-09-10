module Api
  module V1
    module Accounts
      module JrcAi
        class CockpitController < BaseController
          def show
            render json: ::JrcAi::CockpitMetricsService.new(
              account: Current.account,
              user: Current.user,
              account_user: Current.account_user,
              period: params[:period]
            ).perform
          end
        end
      end
    end
  end
end
