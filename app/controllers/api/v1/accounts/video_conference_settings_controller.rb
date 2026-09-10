class Api::V1::Accounts::VideoConferenceSettingsController < Api::V1::Accounts::BaseController
  before_action :ensure_super_admin!, except: :me
  before_action :set_agent, only: [:update, :destroy]

  def index
    settings = Current.account.video_conference_settings.includes(:user).order(:user_id)
    render json: settings.map { |setting| admin_payload(setting) }
  end

  def me
    response.headers['Cache-Control'] = 'no-store'
    setting = Current.account.video_conference_settings.find_by(user: Current.user)
    unless setting&.configured?
      return render json: {
        configured: false,
        moderator_url: nil,
        spectator_url: nil,
        moderator_password: nil,
        spectator_password: nil
      }
    end

    render json: {
      configured: true,
      moderator_url: setting.moderator_url.presence,
      spectator_url: setting.spectator_url.presence,
      moderator_password: setting.moderator_url.present? ? setting.moderator_password.presence : nil,
      spectator_password: setting.spectator_url.present? ? setting.spectator_password.presence : nil
    }
  end

  def update
    setting = Current.account.video_conference_settings.find_or_initialize_by(user: @agent)
    attributes = setting_params.to_h
    attributes.delete('moderator_password') if attributes['moderator_password'].blank? && setting.persisted?
    attributes.delete('spectator_password') if attributes['spectator_password'].blank? && setting.persisted?
    setting.update!(attributes)

    render json: admin_payload(setting)
  end

  def destroy
    Current.account.video_conference_settings.find_by(user: @agent)&.destroy!
    head :no_content
  end

  private

  def ensure_super_admin!
    return if Current.user.is_a?(SuperAdmin)

    render json: { error: 'Acesso exclusivo do Super Admin' }, status: :forbidden
  end

  def set_agent
    @agent = Current.account.users.find(params[:user_id])
  end

  def setting_params
    params.require(:video_conference_setting).permit(
      :moderator_url,
      :spectator_url,
      :moderator_password,
      :spectator_password
    )
  end

  def admin_payload(setting)
    {
      user_id: setting.user_id,
      user_name: setting.user.available_name,
      user_email: setting.user.email,
      moderator_url: setting.moderator_url.presence,
      spectator_url: setting.spectator_url.presence,
      moderator_password_configured: setting.moderator_password.present?,
      spectator_password_configured: setting.spectator_password.present?,
      configured: setting.configured?
    }
  end
end
