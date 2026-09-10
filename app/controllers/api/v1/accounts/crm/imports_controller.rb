module Api
  module V1
    module Accounts
      module Crm
        class ImportsController < BaseController
          def index
            imports = crm_scope.import_batches.order(created_at: :desc)
            render json: imports
          end

          def show
            import = crm_scope.import_batches.includes(:import_row_errors).find(params[:id])
            render json: import.as_json(include: :import_row_errors)
          end

          def create
            import_batch = crm_scope.import_batches.new(import_batch_params)
            import_batch.status = 'pending'
            import_batch.user_id = current_user.id
            
            if import_batch.save
              JrcCrm::ProcessImportBatchJob.perform_later(import_batch.id)
              render json: import_batch, status: :created
            else
              render json: { errors: import_batch.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def import_batch_params
            params.permit(:import_type, :file)
          end
        end
      end
    end
  end
end
