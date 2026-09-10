class SuperAdmin::SipCredentialsController < SuperAdmin::ApplicationController
  before_action :set_account_and_agent, only: [:update, :destroy]

  def index
    @accounts = Account.order(:name)
    @account = selected_account(@accounts)
    @agents = eligible_agents(@account)
    @telephony_integration = @account&.telephony_integration || @account&.build_telephony_integration
    @credentials_by_user_id = if @account
                                @account.sip_credentials.where(user_id: @agents.select(:id)).index_by(&:user_id)
                              else
                                {}
                              end
    @selected_agent = selected_agent(@agents)
    @credential = @selected_agent ? @credentials_by_user_id[@selected_agent.id] : nil
  end

  def update
    credential = @account.sip_credentials.find_or_initialize_by(user: @agent)
    credential.assign_attributes(attributes_for(credential))
    credential.save!

    redirect_to selected_credential_path, notice: I18n.t('super_admin.sip_credentials.saved')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to selected_credential_path, alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    @account.sip_credentials.find_by(user: @agent)&.destroy!

    redirect_to super_admin_sip_credentials_path(account_id: @account.id),
                notice: I18n.t('super_admin.sip_credentials.removed')
  end

  private

  def selected_account(accounts)
    return if accounts.empty?

    accounts.find_by(id: params[:account_id]) || accounts.first
  end

  def eligible_agents(account)
    return User.none unless account

    account.users.where.not(id: SuperAdmin.select(:id)).order(:name, :email)
  end

  def selected_agent(agents)
    return if agents.empty?

    agents.find_by(id: params[:user_id]) || agents.first
  end

  def set_account_and_agent
    @account = Account.find(params[:account_id])
    @agent = eligible_agents(@account).find(params[:user_id])
  end

  def attributes_for(credential)
    attributes = credential_params.to_h
    attributes.delete('password') if attributes['password'].blank? && credential.persisted?
    attributes
  end

  def selected_credential_path
    super_admin_sip_credentials_path(account_id: @account.id, user_id: @agent.id)
  end

  def credential_params
    params.require(:sip_credential).permit(:wss_server, :sip_domain, :extension, :call_history_extension, :username, :password, :enabled)
  end
end
