# == Schema Information
#
# Table name: jrc_crm_import_row_errors
#
#  id            :bigint           not null, primary key
#  error_message :text
#  row_data      :jsonb
#  row_number    :integer
#  created_at    :datetime         not null
#  batch_id      :bigint
#
# Indexes
#
#  index_jrc_crm_import_row_errors_on_batch_id  (batch_id)
#
module JrcCrm
  class ImportRowError < ApplicationRecord
    self.table_name = 'jrc_crm_import_row_errors'
    
    belongs_to :batch, class_name: 'JrcCrm::ImportBatch'
    
    validates :row_number, :error_message, presence: true
  end
end
