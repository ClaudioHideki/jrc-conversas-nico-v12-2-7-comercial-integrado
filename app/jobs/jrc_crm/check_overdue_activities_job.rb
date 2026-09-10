module JrcCrm
  class CheckOverdueActivitiesJob < ApplicationJob
    queue_as :jrc_crm_scheduled

    def perform
      JrcCrm::Activity.where(completed_at: nil).where('due_at < ?', Time.current).find_each do |activity|
        # Only notify once
        next if Notification.exists?(primary_actor: activity, notification_type: 'crm_activity_overdue')

        if activity.deal&.owner_id
          Notification.create!(
            account_id: activity.account_id,
            user_id: activity.deal.owner_id,
            notification_type: 'crm_activity_overdue',
            primary_actor: activity
          )
        end
      end
    end
  end
end
