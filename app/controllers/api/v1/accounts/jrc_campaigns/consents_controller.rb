class Api::V1::Accounts::JrcCampaigns::ConsentsController < Api::V1::Accounts::JrcCampaigns::BaseController
  def index
    render json: scope.order(created_at: :desc).as_json(only: fields)
  end

  def create
    consent = scope.new(params.require(:consent).permit(:phone_number, :evidence))
    consent.assign_attributes(recorded_by: Current.user, granted_at: Time.current)
    if consent.save
      render json: consent.as_json(only: fields), status: :created
    else
      render json: { errors: consent.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    scope.find(params[:id]).update!(revoked_at: Time.current)
    head :no_content
  end

  private

  def scope
    JrcCampaigns::Consent.where(account: Current.account)
  end

  def fields
    [:id, :phone_number, :evidence, :granted_at, :recorded_by_id, :revoked_at]
  end
end
