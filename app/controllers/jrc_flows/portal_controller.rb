class JrcFlows::PortalController < ActionController::Base
  before_action { head :not_found unless JrcFlows::Access.external_beta? }
  def show
    @portal_config = {}
    origin = "'self'"
    if params[:public_id]
      connection = JrcFlowConnection.find_by!(public_id: params[:public_id])
      @portal_config = { accountId: connection.account_id, connectionId: connection.id, name: connection.name, origin: connection.base_url }
      origin += " #{connection.base_url}"
    end
    # Only this view can be framed, by the registered Chatwoot origin.
    response.headers.delete('X-Frame-Options')
    response.headers['Content-Security-Policy'] = "frame-ancestors #{origin}; object-src 'none'; base-uri 'self'"
    response.headers['Referrer-Policy'] = 'no-referrer'
    response.headers['Cache-Control'] = 'no-store'
    render layout: false
  end
end
