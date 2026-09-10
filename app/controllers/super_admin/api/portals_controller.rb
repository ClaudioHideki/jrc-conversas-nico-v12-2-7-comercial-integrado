class SuperAdmin::Api::PortalsController < SuperAdmin::Api::BaseController
  def index
    @current_page = params[:page] || 1
    @portals = current_account.portals
    render 'api/v1/accounts/portals/index'
  end
end
