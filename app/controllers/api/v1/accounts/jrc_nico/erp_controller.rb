class Api::V1::Accounts::JrcNico::ErpController < Api::V1::Accounts::BaseController
  before_action :ensure_administrator
  before_action :set_conversation

  def show
    render json: snapshot
  end

  def update
    setting = JrcNico::ErpSetting.find_or_initialize_by(account_id: Current.account.id)
    setting.update!(params.permit(:mode, :operator_company_id, :requester_user_id))
    render json: snapshot
  rescue ActiveRecord::RecordInvalid
    render json: { error: 'invalid_configuration' }, status: :unprocessable_entity
  end

  def bind
    setting = JrcNico::ErpSetting.find_by!(account_id: Current.account.id)
    raise JrcNico::ErpClient::Error unless %w[fixture live].include?(setting.mode)

    resolved = JrcNico::ErpClient.new.call('resolve', { account_id: Current.account.id, mode: setting.mode, cnpj: params[:cnpj].to_s })
    binding = JrcNico::ErpBinding.find_or_initialize_by(account_id: Current.account.id, contact_id: @conversation.contact_id)
    binding.update!(cnpj: resolved.fetch('cnpj'), customer_name: resolved.fetch('name'),
                    bemtevi_customer_id: resolved.fetch('bemtevi_customer_id'), helpdesk_company_id: resolved.fetch('helpdesk_company_id'),
                    mode: setting.mode, enabled: true, version: SecureRandom.hex(12), verified_by: Current.user)
    render json: snapshot
  rescue JrcNico::ErpClient::Error, ActiveRecord::RecordInvalid, KeyError
    render json: { error: 'erp_binding_unavailable' }, status: :unprocessable_entity
  end

  def revoke
    binding = JrcNico::ErpBinding.find_by(account_id: Current.account.id, contact_id: @conversation.contact_id)
    binding&.update!(enabled: false, version: SecureRandom.hex(12))
    render json: snapshot
  end

  private

  def ensure_administrator
    allowed = JrcNico::ErpContext.account_allowed?(Current.account) && Current.user.is_a?(User) && Current.account.custom_attributes['nico_enabled'] == true &&
              Current.account.account_users.find_by(user_id: Current.user.id)&.administrator?
    render json: { error: 'erp_forbidden' }, status: :forbidden unless allowed
  end

  def set_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    JrcNico::Access.new(account: Current.account, user: Current.user, conversation: @conversation).authorize!
  end

  def snapshot
    setting = JrcNico::ErpSetting.find_by(account_id: Current.account.id)
    binding = JrcNico::ErpBinding.find_by(account_id: Current.account.id, contact_id: @conversation.contact_id)
    { settings: setting&.attributes&.slice('mode', 'operator_company_id', 'requester_user_id') || { mode: 'off' },
      binding: binding&.public_snapshot, external_writes_enabled: false, access: 'administrators_only' }
  end
end
