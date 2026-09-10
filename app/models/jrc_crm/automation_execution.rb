# == Schema Information
#
# Table name: jrc_crm_automation_executions
#
#  id                 :bigint           not null, primary key
#  depth              :integer          default(0), not null
#  error_message      :text
#  event_type         :string           not null
#  finished_at        :datetime
#  metadata           :jsonb
#  started_at         :datetime
#  status             :string           default("pending"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :integer          not null
#  automation_rule_id :bigint           not null
#  correlation_id     :string           not null
#  execution_id       :string           not null
#
# Indexes
#
#  idx_jrc_crm_auto_exec_idempotency                          (account_id,correlation_id,automation_rule_id)
#  index_jrc_crm_automation_executions_on_account_id          (account_id)
#  index_jrc_crm_automation_executions_on_automation_rule_id  (automation_rule_id)
#  index_jrc_crm_automation_executions_on_execution_id        (execution_id) UNIQUE
#  index_jrc_crm_automation_executions_on_status              (status)
#
module JrcCrm
  class AutomationExecution < ApplicationRecord
    self.table_name = 'jrc_crm_automation_executions'
    belongs_to :account
    belongs_to :automation_rule, class_name: 'JrcCrm::AutomationRule'

    validates :account_id, :automation_rule_id, :execution_id, :correlation_id, :status, presence: true
    validates :depth, numericality: { greater_than_or_equal_to: 0 }

    enum status: { pending: 'pending', running: 'running', completed: 'completed', failed: 'failed', skipped_loop: 'skipped_loop' }

    scope :for_correlation, ->(cid) { where(correlation_id: cid) }
    scope :recent, -> { order(created_at: :desc) }
  end
end
