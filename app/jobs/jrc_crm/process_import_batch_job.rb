module JrcCrm
  class ProcessImportBatchJob < ApplicationJob
    queue_as :jrc_crm_imports

    def perform(import_batch_id)
      batch = JrcCrm::ImportBatch.find(import_batch_id)
      Current.account = batch.account

      JrcCrm::ImportProcessorService.new(import_batch: batch).call
    rescue StandardError => e
      batch.update!(status: 'failed')
      Rails.logger.error("Import Batch Failed: #{e.message}")
    end
  end
end
