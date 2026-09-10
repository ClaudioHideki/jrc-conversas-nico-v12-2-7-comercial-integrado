module Api
  module V1
    module Accounts
      module JrcAi
        class BaseController < Api::V1::Accounts::BaseController
          private

          def ensure_ai_administrator!
            raise Pundit::NotAuthorizedError unless Current.account_user&.administrator?
          end
        end
      end
    end
  end
end
