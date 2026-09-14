module JrcCrm
  class ExecuteAutomationJob < ApplicationJob
    queue_as :jrc_crm_automations
    RESOURCE_TYPES = { 'Deal' => 'JrcCrm::Deal', 'Lead' => 'JrcCrm::Lead',
                       'Activity' => 'JrcCrm::Activity', 'Proposal' => 'JrcCrm::Proposal' }.freeze
    
    def perform(automation_rule_id, resource_type, resource_id, account_id)
      account = Account.find(account_id)
      return unless account.active? && account.feature_enabled?('jrc_crm')

      rule = account.jrc_crm_automation_rules.find(automation_rule_id)
      return unless rule.active?
      
      resource_class = RESOURCE_TYPES.fetch(resource_type).constantize
      resource = resource_class.where(account_id: account.id).find(resource_id)

      Current.set(account: account) do
        JrcCrm::AutomationRunnerService.new(
          rule: rule,
          resource: resource,
          account: account, correlation_id: job_id
        ).call
      end
    end
  end
end
