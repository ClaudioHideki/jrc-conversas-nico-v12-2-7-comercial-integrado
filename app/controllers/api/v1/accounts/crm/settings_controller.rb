module Api
  module V1
    module Accounts
      module Crm
        class SettingsController < BaseController
          def show
            settings = {
              default_pipeline_id: crm_scope.custom_attributes['default_pipeline_id'],
              require_lost_reason: crm_scope.custom_attributes['require_lost_reason'] || false
            }
            render json: settings
          end

          def update
            updated_attributes = crm_scope.custom_attributes.merge(settings_params)
            
            if crm_scope.update(custom_attributes: updated_attributes)
              render json: { message: 'Settings updated successfully' }
            else
              render json: { errors: crm_scope.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def settings_params
            params.require(:settings).permit(:default_pipeline_id, :require_lost_reason).to_h
          end
        end
      end
    end
  end
end
