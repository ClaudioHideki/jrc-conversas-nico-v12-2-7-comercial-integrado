class Api::V1::Accounts::JrcRemoteFlowsController < Api::V1::Accounts::JrcFlowsController
  before_action :require_external_beta
  before_action :require_flow_admin

  def require_external_beta
    head :not_found unless JrcFlows::Access.external_beta?
  end

  def index
    counts = JrcFlowRemoteSession.where(connection: connection).group(:flow_id).count
    render json: scope.order(updated_at: :desc).map { |flow| flow.snapshot.except('graph', 'workflow').merge(run_count: counts.fetch(flow.id, 0)) }
  end

  def metadata
    catalog = connection.catalog.merge('inboxes' => connection.catalog.fetch('inboxes', []).select { |i| connection.inbox_ids.include?(i['id']) })
    render json: catalog.merge(capabilities: { crm: false, nico: false, voice: false, remote: true }, stages: [], triggers: ['message_created'])
  end

  def validate_definition
    render json: { errors: JrcFlows::RemoteDefinition.new(candidate_flow).errors }
  end

  def simulate
    return super if @flow.engine == 'workflow'
    candidate = candidate_flow
    errors = JrcFlows::Definition.new(candidate).errors(complete: false)
    return render json: { errors: errors }, status: :unprocessable_entity if errors.any?
    render json: JrcFlows::Simulator.new(candidate, params.permit(responses: [])[:responses]).perform
  end

  def pause
    @flow.update!(status: 'paused')
    JrcFlowRemoteSession.where(flow: @flow, status: %w[ready running waiting delayed]).update_all(status: 'paused', wake_at: nil, error: 'Flow pausado.')
    render json: @flow.snapshot
  end

  def runs
    records = JrcFlowRemoteSession.where(connection: connection, flow: @flow).order(id: :desc)
    records = records.where('id < ?', params[:before].to_i) if params[:before].present?
    render json: records.limit(30).map(&:snapshot)
  end

  def stop_run
    run = JrcFlowRemoteSession.find_by!(connection: connection, flow: @flow, id: params.require(:run_id))
    run.update!(status: 'paused', error: 'Execução interrompida pelo administrador.', finished_at: Time.current, wake_at: nil)
    render json: run.snapshot
  end

  def destroy
    return render json: { error: 'Pause antes de excluir.' }, status: :conflict if @flow.status == 'active'
    return render json: { error: 'O flow possui histórico remoto. Mantenha-o pausado para preservar a auditoria.' }, status: :conflict if JrcFlowRemoteSession.exists?(flow: @flow)
    super
  end

  private

  def connection
    @connection ||= JrcFlowConnection.find_by!(account: Current.account, id: params[:jrc_flow_connection_id])
  end

  def scope
    JrcFlow.where(account: Current.account, connection: connection)
  end
end
