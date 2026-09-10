module Api
  module V1
    module Accounts
      module Crm
        class WalletsController < BaseController
          def show
            wallet_data = JrcCrm::WalletService.new(
              account: crm_scope,
              user: Current.user,
              admin: crm_admin?,
              params: params
            ).call

            render json: wallet_data
          end
        end
      end
    end
  end
end
