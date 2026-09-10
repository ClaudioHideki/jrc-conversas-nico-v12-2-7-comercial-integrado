# == Schema Information
#
# Table name: jrc_crm_automation_rules
#
#  id               :bigint           not null, primary key
#  actions          :jsonb
#  active           :boolean          default(TRUE), not null
#  conditions       :jsonb
#  description      :text
#  execution_count  :integer          default(0), not null
#  last_executed_at :datetime
#  name             :string           not null
#  trigger_type     :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :integer          not null
#
# Indexes
#
#  index_jrc_crm_automation_rules_on_account_id    (account_id)
#  index_jrc_crm_automation_rules_on_active        (active)
#  index_jrc_crm_automation_rules_on_trigger_type  (trigger_type)
#
module JrcCrm
  class AutomationRule < ApplicationRecord
    self.table_name = 'jrc_crm_automation_rules'
    
    belongs_to :account
    has_many :executions, class_name: 'JrcCrm::AutomationExecution', foreign_key: :automation_rule_id
    
    validates :name, :trigger_type, presence: true
    
    TRIGGER_TYPES = %w[deal_created stage_changed deal_won deal_lost activity_overdue message_received proposal_sent proposal_viewed proposal_accepted]
    validates :trigger_type, inclusion: { in: TRIGGER_TYPES }
    
    scope :active, -> { where(active: true) }
    scope :for_trigger, ->(type) { active.where(trigger_type: type) }
  end
end
