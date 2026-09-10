module JrcCrm
  class DispatchN8nEventJob < ApplicationJob
    queue_as :jrc_crm_webhooks

    def perform(account_id, resource_type, resource_id, event_name)
      JrcCrm::N8nEventDispatcherService.new(
        account_id: account_id,
        resource_type: resource_type,
        resource_id: resource_id,
        event_name: event_name
      ).call
    end
  end
end
