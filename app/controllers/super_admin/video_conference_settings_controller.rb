class SuperAdmin::VideoConferenceSettingsController < SuperAdmin::ApplicationController
  before_action :set_account_and_agent, only: [:update, :destroy]

  def index
    @accounts = Account.order(:name)
    @account = selected_account(@accounts)
    @agents = eligible_agents(@account)
    @settings_by_user_id = if @account
                             @account.video_conference_settings.where(user_id: @agents.select(:id)).index_by(&:user_id)
                           else
                             {}
                           end
    @selected_agent = selected_agent(@agents)
    @setting = @selected_agent ? @settings_by_user_id[@selected_agent.id] : nil
  end

  def update
    setting = @account.video_conference_settings.find_or_initialize_by(user: @agent)
    attributes = setting_params.to_h
    attributes.delete('moderator_password') if attributes['moderator_password'].blank? && setting.persisted?
    attributes.delete('spectator_password') if attributes['spectator_password'].blank? && setting.persisted?
    setting.assign_attributes(attributes)
    setting.save!

    redirect_to selected_setting_path, notice: I18n.t('super_admin.video_conference_settings.saved')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to selected_setting_path, alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    @account.video_conference_settings.find_by(user: @agent)&.destroy!

    redirect_to super_admin_video_conference_settings_path(account_id: @account.id),
                notice: I18n.t('super_admin.video_conference_settings.removed')
  end

  private

  def selected_account(accounts)
    return if accounts.empty?

    accounts.find_by(id: params[:account_id]) || accounts.first
  end

  def eligible_agents(account)
    return User.none unless account

    agents = account.users.where.not(id: SuperAdmin.select(:id)).order(:name, :email)
    return agents if params[:query].blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query])}%"
    agents.where('users.name ILIKE :query OR users.email ILIKE :query', query: query)
  end

  def selected_agent(agents)
    return if agents.empty?

    agents.find_by(id: params[:user_id]) || agents.first
  end

  def set_account_and_agent
    @account = Account.find(params[:account_id])
    @agent = @account.users.where.not(id: SuperAdmin.select(:id)).find(params[:user_id])
  end

  def selected_setting_path
    super_admin_video_conference_settings_path(account_id: @account.id, user_id: @agent.id)
  end

  def setting_params
    params.require(:video_conference_setting).permit(
      :moderator_url,
      :spectator_url,
      :moderator_password,
      :spectator_password
    )
  end
end
