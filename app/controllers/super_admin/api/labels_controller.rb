class SuperAdmin::Api::LabelsController < SuperAdmin::Api::BaseController
  def index
    @labels = current_account.labels
    render 'api/v1/accounts/labels/index'
  end
end
