# == Schema Information
#
# Table name: jrc_crm_import_batches
#
#  id              :bigint           not null, primary key
#  duplicate_count :integer          default(0)
#  error_count     :integer          default(0)
#  file_name       :string
#  import_type     :string           default("leads")
#  row_count       :integer
#  status          :string           default("pending")
#  success_count   :integer          default(0)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :integer          not null
#  user_id         :integer
#
# Indexes
#
#  index_jrc_crm_import_batches_on_account_id  (account_id)
#  index_jrc_crm_import_batches_on_status      (status)
#  index_jrc_crm_import_batches_on_user_id     (user_id)
#
module JrcCrm
  class ImportBatch < ApplicationRecord
    self.table_name = 'jrc_crm_import_batches'
    
    belongs_to :account
    belongs_to :user
    has_many :import_row_errors, class_name: 'JrcCrm::ImportRowError', foreign_key: :batch_id, dependent: :destroy
    
    validates :file_name, :import_type, presence: true
    
    enum status: { pending: 'pending', processing: 'processing', completed: 'completed', failed: 'failed' }
    enum import_type: { leads: 'leads', deals: 'deals' }
  end
end
