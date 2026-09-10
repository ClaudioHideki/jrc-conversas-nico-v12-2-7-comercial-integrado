module JrcCrm
  class WalletService
    def initialize(account:, user:, admin: false, params: {})
      @account = account
      @user = user
      @params = params
      @admin = admin
    end

    def call
      deals = fetch_deals
      leads = fetch_leads
      activities = fetch_activities
      hot_deals = fetch_hot_deals
      {
        active_deals: deals.map { |deal| JrcCrm::DealSerializer.new(deal).as_json },
        active_leads: leads.map { |lead| JrcCrm::LeadSerializer.new(lead).as_json },
        todays_activities: activities.map { |activity| JrcCrm::ActivitySerializer.new(activity).as_json },
        hot_deals: hot_deals.map { |deal| JrcCrm::DealSerializer.new(deal).as_json },
        totals: {
          active_deals_count: base_deals.count,
          active_leads_count: base_leads.count,
          todays_activities_count: base_todays_activities.count,
          active_deals_value_cents: base_deals.sum(:value_cents)
        },
        owner: { id: @user.id, name: @user.name }
      }
    end

    private

    def base_deals
      deals = @account.jrc_crm_deals.where(status: 'open')
      deals = deals.where(owner_id: @user.id) unless admin_viewing_all?
      deals
    end

    def base_leads
      leads = @account.jrc_crm_leads.where(status: 'new')
      leads = leads.where(owner_id: @user.id) unless admin_viewing_all?
      leads
    end

    def base_todays_activities
      activities = @account.jrc_crm_activities.pending.where(due_at: Time.zone.today.all_day)
      activities = activities.where(user_id: @user.id) unless admin_viewing_all?
      activities
    end

    def fetch_deals
      base_deals.includes(:pipeline, :stage, :owner, :team, :contact, :contacts, :proposals, :products,
                          :activities, deal_conversations: :conversation).order(updated_at: :desc).limit(10)
    end

    def fetch_leads
      base_leads.includes(:owner, :team, :conversation).order(created_at: :desc).limit(10)
    end

    def fetch_activities
      base_todays_activities.includes(:user, :deal, :lead).order(due_at: :asc)
    end

    def fetch_hot_deals
      base_deals.includes(:pipeline, :stage, :owner, :team, :contact, :contacts, :proposals, :products,
                          :activities, deal_conversations: :conversation)
                .where('expected_close_at <= ?', 7.days.from_now).order(expected_close_at: :asc).limit(5)
    end

    def admin_viewing_all?
      @admin && @params[:view_all] == 'true'
    end
  end
end
