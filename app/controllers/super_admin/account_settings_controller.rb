class SuperAdmin::AccountSettingsController < SuperAdmin::ApplicationController
  SECTIONS = {
    'general' => 'Conta',
    'agents' => 'Agentes',
    'teams' => 'Times',
    'inboxes' => 'Caixas de Entrada',
    'labels' => 'Etiquetas',
    'custom_attributes' => 'Atributos Personalizados',
    'automations' => 'Automacao',
    'agent_bots' => 'Robos',
    'macros' => 'Macros',
    'canned_responses' => 'Respostas Prontas',
    'integrations' => 'Integracoes'
  }.freeze

  CHANNEL_TYPES = {
    'api' => 'API',
    'email' => 'Email',
    'web_widget' => 'Website',
    'line' => 'LINE',
    'telegram' => 'Telegram',
    'sms' => 'SMS'
  }.freeze

  helper_method :account_setting_path, :account_setting_resource_path, :settings_sections

  before_action :set_accounts
  before_action :set_account
  before_action :set_section
  before_action :load_records, only: :show

  def show; end

  def create
    dispatch_resource_action(:create)
    redirect_to account_setting_path(@section), notice: 'Configuracao criada com sucesso.'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to account_setting_path(@section), alert: e.record.errors.full_messages.to_sentence
  rescue StandardError => e
    redirect_to account_setting_path(@section), alert: e.message
  end

  def update
    dispatch_resource_action(:update)
    redirect_to account_setting_path(@section), notice: 'Configuracao atualizada com sucesso.'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to account_setting_path(@section), alert: e.record.errors.full_messages.to_sentence
  rescue StandardError => e
    redirect_to account_setting_path(@section), alert: e.message
  end

  def destroy
    dispatch_resource_action(:destroy)
    redirect_to account_setting_path(@section), notice: 'Registro removido com sucesso.'
  rescue StandardError => e
    redirect_to account_setting_path(@section), alert: e.message
  end

  private

  def set_accounts
    @accounts = Account.order(:name)
  end

  def set_account
    @account = @accounts.find(params[:account_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to super_admin_root_path, alert: 'Conta nao encontrada.'
  end

  def set_section
    @section = params[:section].presence || 'general'
    @section = 'general' unless SECTIONS.key?(@section)
  end

  def load_records
    @agents = @account.users.includes(:account_users).order_by_full_name
    @teams = @account.teams.includes(:members).order(:name)
    @inboxes = @account.inboxes.includes(:channel, :members).order_by_name
    @labels = @account.labels.order(:title)
    @custom_attributes = @account.custom_attribute_definitions.order(:attribute_model, :attribute_display_name)
    @automation_rules = @account.automation_rules.order(:name)
    @agent_bots = @account.agent_bots.order(:name)
    @macros = @account.macros.order(:name)
    @canned_responses = @account.canned_responses.order(:short_code)
    @integrations = @account.hooks.order(:app_id)
    @available_apps = Integrations::App.all.select { |app| app.active?(@account) }
  end

  def settings_sections
    SECTIONS
  end

  def account_setting_path(section = @section, account = @account)
    "/super_admin/accounts/#{account.id}/settings/#{section}"
  end

  def account_setting_resource_path(resource, id = nil, section: @section, account: @account)
    path = "#{account_setting_path(section, account)}/#{resource}"
    id.present? ? "#{path}/#{id}" : path
  end

  def dispatch_resource_action(action)
    resource = params[:resource].to_s
    method = "#{action}_#{resource}"
    raise ActionController::RoutingError, 'Recurso invalido' unless respond_to?(method, true)

    send(method)
  end

  def create_agent
    AgentBuilder.new(
      email: agent_params[:email],
      name: agent_params[:name],
      role: agent_params[:role],
      availability: agent_params[:availability],
      auto_offline: checkbox_value(agent_params[:auto_offline]),
      inviter: current_super_admin,
      account: @account
    ).perform
  end

  def update_agent
    account_user = account_user_from_param
    account_user.update!(agent_account_user_params)
    account_user.user.update!(agent_user_params) if agent_user_params.present?
  end

  def destroy_agent
    account_user_from_param.destroy!
  end

  def update_account
    @account.update!(account_params)
  end

  def create_team
    team = @account.teams.create!(team_params)
    sync_members(team, params.dig(:team, :member_ids))
  end

  def update_team
    team = @account.teams.find(params[:id])
    team.update!(team_params)
    sync_members(team, params.dig(:team, :member_ids))
  end

  def destroy_team
    @account.teams.find(params[:id]).destroy!
  end

  def create_inbox
    channel = build_channel!
    @account.inboxes.create!(inbox_params.merge(channel: channel))
  end

  def update_inbox
    inbox = @account.inboxes.find(params[:id])
    inbox.update!(inbox_params)
    update_channel(inbox)
    sync_members(inbox, params.dig(:inbox, :member_ids))
  end

  def destroy_inbox
    @account.inboxes.find(params[:id]).destroy!
  end

  def create_label
    @account.labels.create!(label_params)
  end

  def update_label
    @account.labels.find(params[:id]).update!(label_params)
  end

  def destroy_label
    label = @account.labels.find(params[:id])
    label_title = label.title
    label.destroy!
    Labels::RemoveAssociationsJob.perform_later(
      label_title: label_title,
      account_id: @account.id,
      label_deleted_at: Time.current
    )
  end

  def create_custom_attribute
    @account.custom_attribute_definitions.create!(custom_attribute_params)
  end

  def update_custom_attribute
    @account.custom_attribute_definitions.find(params[:id]).update!(custom_attribute_params)
  end

  def destroy_custom_attribute
    @account.custom_attribute_definitions.find(params[:id]).destroy!
  end

  def create_automation
    @account.automation_rules.create!(automation_params)
  end

  def update_automation
    @account.automation_rules.find(params[:id]).update!(automation_params)
  end

  def destroy_automation
    @account.automation_rules.find(params[:id]).destroy!
  end

  def create_agent_bot
    @account.agent_bots.create!(agent_bot_params)
  end

  def update_agent_bot
    @account.agent_bots.find(params[:id]).update!(agent_bot_params)
  end

  def destroy_agent_bot
    @account.agent_bots.find(params[:id]).destroy!
  end

  def create_macro
    @account.macros.create!(macro_params.merge(created_by_id: current_super_admin.id, updated_by_id: current_super_admin.id))
  end

  def update_macro
    @account.macros.find(params[:id]).update!(macro_params.merge(updated_by_id: current_super_admin.id))
  end

  def destroy_macro
    @account.macros.find(params[:id]).destroy!
  end

  def create_canned_response
    @account.canned_responses.create!(canned_response_params)
  end

  def update_canned_response
    @account.canned_responses.find(params[:id]).update!(canned_response_params)
  end

  def destroy_canned_response
    @account.canned_responses.find(params[:id]).destroy!
  end

  def create_integration
    @account.hooks.create!(integration_params)
  end

  def update_integration
    @account.hooks.find(params[:id]).update!(integration_update_params)
  end

  def destroy_integration
    @account.hooks.find(params[:id]).destroy!
  end

  def account_user_from_param
    @account.account_users.find(params[:id])
  end

  def sync_members(record, member_ids)
    ids = Array(member_ids).reject(&:blank?).map(&:to_i)
    ids &= @account.users.pluck(:id)
    record.members = @account.users.where(id: ids)
  end

  def build_channel!
    case params.dig(:inbox, :channel_type)
    when 'api'
      @account.api_channels.create!(api_channel_params)
    when 'email'
      @account.email_channels.create!(email_channel_params)
    when 'web_widget'
      @account.web_widgets.create!(web_widget_channel_params)
    when 'line'
      @account.line_channels.create!(line_channel_params)
    when 'telegram'
      @account.telegram_channels.create!(telegram_channel_params)
    when 'sms'
      @account.sms_channels.create!(sms_channel_params)
    else
      raise 'Tipo de canal nao suportado para criacao nativa.'
    end
  end

  def update_channel(inbox)
    attrs = channel_params_for(inbox.channel_type)
    return if attrs.blank?

    inbox.channel.update!(attrs)
  end

  def channel_params_for(channel_type)
    return {} unless params[:channel].present?

    case channel_type
    when 'Channel::Api' then api_channel_params
    when 'Channel::Email' then email_channel_update_params
    when 'Channel::WebWidget' then web_widget_channel_params
    when 'Channel::Line' then line_channel_update_params
    when 'Channel::Telegram' then telegram_channel_update_params
    when 'Channel::Sms' then sms_channel_params
    else {}
    end
  end

  def account_params
    params.require(:account).permit(:name, :locale, :domain, :support_email, :status, :auto_resolve_duration)
  end

  def agent_params
    params.require(:agent).permit(:name, :email, :role, :availability, :auto_offline)
  end

  def agent_user_params
    agent_params.slice(:name)
  end

  def agent_account_user_params
    attrs = agent_params.slice(:role, :availability)
    attrs[:auto_offline] = checkbox_value(agent_params[:auto_offline]) if agent_params.key?(:auto_offline)
    attrs
  end

  def team_params
    params.require(:team).permit(:name, :description, :allow_auto_assign, :icon, :icon_color)
  end

  def inbox_params
    attrs = params.require(:inbox).permit(:name, :greeting_enabled, :greeting_message, :enable_auto_assignment, :timezone).to_h
    attrs['timezone'] = attrs['timezone'].presence || 'UTC'
    attrs['greeting_enabled'] = checkbox_value(attrs['greeting_enabled']) if attrs.key?('greeting_enabled')
    attrs['enable_auto_assignment'] = checkbox_value(attrs['enable_auto_assignment']) if attrs.key?('enable_auto_assignment')
    attrs
  end

  def api_channel_params
    attrs = params.require(:channel).permit(:webhook_url, :hmac_mandatory).to_h
    attrs['hmac_mandatory'] = checkbox_value(attrs['hmac_mandatory']) if attrs.key?('hmac_mandatory')
    attrs
  end

  def email_channel_params
    params.require(:channel).permit(:email)
  end

  def email_channel_update_params
    attrs = params.require(:channel).permit(:email, :imap_enabled, :smtp_enabled).to_h
    attrs['imap_enabled'] = checkbox_value(attrs['imap_enabled']) if attrs.key?('imap_enabled')
    attrs['smtp_enabled'] = checkbox_value(attrs['smtp_enabled']) if attrs.key?('smtp_enabled')
    attrs
  end

  def web_widget_channel_params
    params.require(:channel).permit(:website_url, :widget_color, :welcome_title, :welcome_tagline)
  end

  def line_channel_params
    params.require(:channel).permit(:line_channel_id, :line_channel_secret, :line_channel_token)
  end

  def line_channel_update_params
    attrs = line_channel_params.to_h
    attrs.delete('line_channel_secret') if attrs['line_channel_secret'].blank?
    attrs.delete('line_channel_token') if attrs['line_channel_token'].blank?
    attrs
  end

  def sms_channel_params
    params.require(:channel).permit(:phone_number)
  end

  def telegram_channel_params
    params.require(:channel).permit(:bot_token)
  end

  def telegram_channel_update_params
    attrs = telegram_channel_params.to_h
    attrs.delete('bot_token') if attrs['bot_token'].blank?
    attrs
  end

  def label_params
    attrs = params.require(:label).permit(:title, :description, :color, :show_on_sidebar).to_h
    attrs['show_on_sidebar'] = checkbox_value(attrs['show_on_sidebar']) if attrs.key?('show_on_sidebar')
    attrs
  end

  def custom_attribute_params
    attrs = params.require(:custom_attribute_definition).permit(
      :attribute_display_name, :attribute_description, :attribute_display_type,
      :attribute_key, :attribute_model, :regex_pattern, :regex_cue, :attribute_values_text
    ).to_h
    attrs['attribute_values'] = attrs.delete('attribute_values_text').to_s.split("\n").map(&:strip).reject(&:blank?)
    attrs
  end

  def automation_params
    params.require(:automation).permit(:name, :description, :event_name, :active)
          .merge(
            active: checkbox_value(params.dig(:automation, :active)),
            conditions: json_array(params.dig(:automation, :conditions_json)),
            actions: json_array(params.dig(:automation, :actions_json))
          )
  end

  def agent_bot_params
    params.require(:agent_bot).permit(:name, :description, :outgoing_url, :bot_type)
  end

  def macro_params
    params.require(:macro).permit(:name, :visibility)
          .merge(actions: json_array(params.dig(:macro, :actions_json)))
  end

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content)
  end

  def integration_params
    params.require(:integration).permit(:app_id, :status, :hook_type, :inbox_id)
          .merge(settings: json_object(params.dig(:integration, :settings_json)))
  end

  def integration_update_params
    params.require(:integration).permit(:status).merge(settings: json_object(params.dig(:integration, :settings_json)))
  end

  def checkbox_value(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def json_array(value)
    parsed = JSON.parse(value.presence || '[]')
    parsed.is_a?(Array) ? parsed : []
  end

  def json_object(value)
    parsed = JSON.parse(value.presence || '{}')
    parsed.is_a?(Hash) ? parsed : {}
  end
end
