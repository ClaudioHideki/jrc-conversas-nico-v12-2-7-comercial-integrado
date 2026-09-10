module JrcCrm
  class ExecuteAutomationJob < ApplicationJob
    queue_as :jrc_crm_automations
    
    def perform(automation_rule_id, resource_type, resource_id, account_id)
      account = Account.find(account_id)
      Current.account = account
      rule = JrcCrm::AutomationRule.find(automation_rule_id)
      
      resource_class = "JrcCrm::#{resource_type}".constantize
      resource = resource_class.find(resource_id)

      JrcCrm::AutomationRunnerService.new(
        rule: rule,
        resource: resource,
        account: account
      ).call
    end
  end
end
