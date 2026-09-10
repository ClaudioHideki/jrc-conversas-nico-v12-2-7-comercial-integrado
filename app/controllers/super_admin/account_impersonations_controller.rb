class SuperAdmin::AccountImpersonationsController < SuperAdmin::ApplicationController
  before_action :set_account
  before_action :set_administrator

  def show
    unless @administrator
      return redirect_to(
        super_admin_account_path(@account),
        alert: 'Esta conta nao possui administrador para impersonation.'
      )
    end

    redirect_to impersonation_url, allow_other_host: true
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end

  def set_administrator
    account_user = @account.account_users.administrator.includes(:user).order(:id).first
    @administrator = account_user&.user
  end

  def impersonation_url
    encoded_email = ERB::Util.url_encode(@administrator.email)
    encoded_target = ERB::Util.url_encode(safe_target_path)
    encoded_return_to = ERB::Util.url_encode(super_admin_return_path)
    token = @administrator.generate_sso_auth_token(impersonation: true)

    query = {
      email: encoded_email,
      sso_auth_token: token,
      impersonation: true,
      target: encoded_target,
      super_admin_account_id: @account.id,
      super_admin_return_to: encoded_return_to
    }.map { |key, value| "#{key}=#{value}" }.join('&')

    "#{ENV.fetch('FRONTEND_URL', nil)}/app/login?#{query}"
  end

  def safe_target_path
    target = params[:target].to_s
    account_root = "/app/accounts/#{@account.id}"
    return "#{account_root}/settings/general" unless target.start_with?("#{account_root}/")
    return "#{account_root}/settings/general" if target.match?(%r{\A//}) || target.include?('\\')

    target
  end

  def super_admin_return_path
    "/super_admin?account_id=#{@account.id}"
  end
end
