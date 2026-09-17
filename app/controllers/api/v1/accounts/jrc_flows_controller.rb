class Api::V1::Accounts::JrcFlowsController < Api::V1::Accounts::BaseController
  before_action :disable_flow_cache
  before_action :require_flow_access
  before_action :require_flow_admin, except: %i[index metadata runs]
  before_action :set_flow, except: %i[index create metadata import_preview import_definition]
  rescue_from ActiveRecord::StaleObjectError, with: :stale_definition
  rescue_from JrcFlows::Importer::Invalid, JrcFlows::WorkflowEngine::Error do |e|
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def index
    flows = scope.order(updated_at: :desc)
    unless Current.account_user.administrator?
      summaries = flows.map do |flow|
        flow.as_json(only: %i[id name kind status]).merge('inbox_ids' => Array(flow.settings['inbox_ids']) & accessible_inbox_ids)
      end
      return render json: summaries
    end
    counts = JrcFlowRun.where(account: Current.account).group(:flow_id).count
    render json: flows.map { |flow| flow.snapshot.except('graph', 'workflow').merge(run_count: counts.fetch(flow.id, 0)) }
  end

  def show
    render json: @flow.snapshot
  end

  def create
    flow = scope.new(flow_params.except(:lock_version).merge(created_by: Current.user, status: 'draft'))
    flow.save!
    render json: flow.snapshot, status: :created
  end

  def update
    return render json: { error: 'Pause o fluxo antes de editar.' }, status: :conflict if @flow.status == 'active'

    @flow.update!(flow_params)
    render json: @flow.snapshot
  end

  def destroy
    return render json: { error: 'Pause o fluxo antes de excluir.' }, status: :conflict if @flow.status == 'active'

    @flow.destroy!
    head :no_content
  end

  def activate
    @flow.with_lock do
      next_run = @flow.settings['trigger'] == 'schedule' ? @flow.settings['interval_minutes'].to_i.minutes.from_now : nil
      @flow.update!(status: 'active', created_by: Current.user, next_run_at: next_run)
    end
    render json: @flow.snapshot
  end

  def pause
    @flow.update!(status: 'paused')
    @flow.runs.live.update_all(status: 'paused', error: 'Fluxo pausado pelo administrador.', finished_at: Time.current, wake_at: nil)
    render json: @flow.snapshot
  end

  def duplicate
    copy = @flow.dup
    copy.assign_attributes(name: "#{@flow.name.first(110)} (cópia)", created_by: Current.user, status: 'draft')
    copy.credential_ciphertext = nil
    copy.save!
    render json: copy.snapshot, status: :created
  end

  def validate_definition
    candidate = candidate_flow
    render json: { errors: JrcFlows::Definition.new(candidate).errors }
  end

  def simulate
    if @flow.engine == 'workflow'
      candidate = candidate_flow
      event = params[:event_type] == 'START' ? 'START' : 'MESSAGE'
      result = JrcFlows::WorkflowEngine.new(candidate, simulation: true).perform({ 'event_type' => event, 'mensagem' => Array(params[:responses]).first.to_s, 'conversation_id' => 'playground', 'message_id' => SecureRandom.uuid, 'tenant_id' => "jrc-test-#{Current.account.id}" })
      return render json: result
    end

    candidate = candidate_flow
    errors = JrcFlows::Definition.new(candidate).errors
    return render json: { errors: errors }, status: :unprocessable_entity if errors.any?

    render json: JrcFlows::Simulator.new(candidate, params.permit(responses: [])[:responses]).perform
  end

  def runs
    records = @flow.runs.includes(conversation: :contact).order(id: :desc)
    unless Current.account_user.administrator?
      records = records.joins(:conversation).where(conversations: { inbox_id: accessible_inbox_ids })
      summaries = records.limit(30).map do |run|
        run.as_json(only: %i[id status created_at finished_at]).merge('conversation_id' => run.conversation.display_id)
      end
      return render json: summaries
    end
    records = records.where('id < ?', params[:before].to_i) if params[:before].present?
    render json: records.limit(30).map(&:snapshot)
  end

  def start
    return render json: { error: 'O fluxo precisa estar ativo e usar o gatilho manual.' }, status: :unprocessable_entity unless @flow.status == 'active' && @flow.settings['trigger'] == 'manual'

    conversation = Current.account.conversations.find_by!(display_id: params.require(:conversation_id))
    unless Array(@flow.settings['inbox_ids']).map(&:to_i).include?(conversation.inbox_id)
      return render json: { error: 'A conversa não pertence às caixas deste fluxo.' }, status: :unprocessable_entity
    end
    if JrcFlowRun.live.exists?(conversation: conversation) || conversation.assignee_agent_bot_id.present? ||
       (@flow.settings.fetch('pause_on_agent', true) && conversation.assignee_id.present?) ||
       (@flow.settings.fetch('pause_on_team', false) && conversation.team_id.present?)
      return render json: { error: 'A conversa já está em atendimento. Libere a atribuição ou encerre a execução atual.' }, status: :conflict
    end
    JrcFlows::DispatchJob.perform_later(Current.account.id, conversation.id, 'manual', "manual:#{SecureRandom.uuid}", nil, nil, @flow.id)
    head :accepted
  end

  def stop_run
    run = @flow.runs.find(params.require(:run_id))
    run.conversation.with_lock do
      run.with_lock do
        if %w[running waiting delayed].include?(run.status)
          run.update!(status: 'paused', error: 'Execução interrompida pelo administrador.', finished_at: Time.current, wake_at: nil)
        end
      end
    end
    render json: run.snapshot
  end

  def metadata
    account = Current.account
    unless Current.account_user.administrator?
      return render json: {
        inboxes: account.inboxes.where(id: accessible_inbox_ids).order(:name).as_json(only: %i[id name]),
        capabilities: { manage: false, broker: JrcBroker::Configuration.enabled? && account.feature_enabled?('jrc_broker') }
      }
    end
    render json: {
      inboxes: account.inboxes.order(:name).pluck(:id, :name, :channel_type).map { |id, name, channel_type| { id: id, name: name, channel_type: channel_type } },
      agents: account.users.order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name } },
      teams: account.teams.order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name } },
      labels: account.labels.order(:title).pluck(:title),
      stages: account.feature_enabled?('jrc_crm') ? JrcCrm::Stage.where(account: account, active: true).includes(:pipeline).map { |stage| { id: stage.id, name: "#{stage.pipeline.name} / #{stage.name}" } } : [],
      capabilities: { crm: account.feature_enabled?('jrc_crm'), nico: account.custom_attributes['nico_enabled'] == true && ENV['NICO_MODE'] == 'provider', voice: false },
      triggers: JrcFlows::Definition::TRIGGERS
    }
  end

  def import_preview
    render json: JrcFlows::Importer.new(params.require(:content)).preview
  end

  def import_definition
    attributes = JrcFlows::Importer.new(params.require(:content)).attributes
    attributes['settings'] = attributes.fetch('settings', {}).merge('inbox_ids' => Array(params.permit(inbox_ids: [])[:inbox_ids]).map(&:to_i))
    attributes['name'] = params[:name] if params[:name].is_a?(String)
    flow = scope.new(attributes.merge(created_by: Current.user, status: 'draft'))
    flow.save!
    render json: flow.snapshot, status: :created
  end

  def export_definition
    output = params[:original] == 'true' && @flow.engine == 'workflow' ? @flow.source_definition : @flow.export_definition
    render json: output
  end

  private

  def disable_flow_cache
    response.headers['Cache-Control'] = 'no-store'
  end

  def require_flow_access
    raise Pundit::NotAuthorizedError unless Current.user.is_a?(User) && Current.account_user && JrcFlows::Access.enabled?(Current.account)
  end

  def accessible_inbox_ids
    @accessible_inbox_ids ||= Current.account.inboxes.joins(:inbox_members).where(inbox_members: { user_id: Current.user.id }).pluck(:id)
  end

  def require_flow_admin
    raise Pundit::NotAuthorizedError unless Current.user.is_a?(User) && Current.account_user&.administrator?
  end

  def scope
    flows = JrcFlow.where(account: Current.account, connection_id: nil)
    return flows if Current.account_user.administrator?
    return flows.none if accessible_inbox_ids.empty?

    flows.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(settings->'inbox_ids') AS inbox_id WHERE inbox_id.value IN (?))",
                accessible_inbox_ids.map(&:to_s))
  end

  def set_flow
    @flow = scope.find(params[:id])
  end

  def flow_params
    params.require(:flow).permit(:name, :description, :kind, :lock_version, :workflow_json, graph: {}, settings: {}, connection_secrets: [:openai_api_key, :http_api_key])
  end

  def candidate_flow
    candidate = @flow.dup
    candidate.assign_attributes(flow_params.except(:lock_version)) if params[:flow]
    candidate
  end

  def stale_definition
    render json: { error: 'O fluxo foi alterado em outra sessão. Reabra antes de salvar.' }, status: :conflict
  end
end
