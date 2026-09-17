class Api::V1::Accounts::JrcFlowConnectionsController < Api::V1::Accounts::BaseController
  before_action { head :not_found unless JrcFlows::Access.external_beta? && JrcFlows::Access.enabled?(Current.account) }
  before_action :require_admin
  before_action :set_connection, except: %i[index create]
  rescue_from JrcFlows::ChatwootClient::Error, ArgumentError do |e|
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def index
    render json: scope.order(:name).map(&:snapshot)
  end

  def create
    connection = scope.create!(connection_params)
    render json: connection.snapshot, status: :created
  end

  def update
    return render json: { error: 'Desconecte antes de alterar as caixas ou credenciais.' }, status: :conflict if @connection.enabled?
    @connection.update!(connection_params.except(:base_url, :remote_account_id))
    render json: @connection.snapshot
  end

  def show
    render json: @connection.snapshot
  end

  def verify
    JrcFlows::ConnectionSetup.new(@connection).verify
    render json: @connection.reload.snapshot
  end

  def install
    JrcFlows::ConnectionSetup.new(@connection).install
    render json: @connection.reload.snapshot
  end

  def disconnect
    JrcFlows::ConnectionSetup.new(@connection).disconnect
    render json: @connection.reload.snapshot
  end

  private

  def scope
    JrcFlowConnection.where(account: Current.account)
  end

  def require_admin
    raise Pundit::NotAuthorizedError unless Current.user.is_a?(User) && Current.account_user&.administrator?
  end

  def set_connection
    @connection = scope.find(params[:id])
  end

  def connection_params
    params.require(:connection).permit(:name, :base_url, :remote_account_id, inbox_ids: [], secrets: [:api_token, :openai_api_key, :http_api_key])
  end
end
