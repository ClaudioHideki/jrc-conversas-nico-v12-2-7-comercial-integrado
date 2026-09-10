class SuperAdmin::AccountInboxesController < DashboardController
  before_action :authenticate_super_admin!
  before_action :set_super_admin_account_context

  private

  def set_super_admin_account_context
    account = Account.find(params[:account_id])
    @global_config ||= {}
    @global_config['SUPER_ADMIN_ACCOUNT'] = super_admin_account_payload(account)
    @global_config['SUPER_ADMIN_USER'] = {
      id: current_super_admin.id,
      name: current_super_admin.available_name,
      email: current_super_admin.email
    }
  rescue ActiveRecord::RecordNotFound
    redirect_to super_admin_root_path, alert: 'Conta nao encontrada.'
  end

  def super_admin_account_payload(account)
    {
      id: account.id,
      name: account.name,
      locale: account.locale,
      status: account.status,
      features: account.enabled_features.index_with(true),
      role: 'administrator'
    }
  end
end
