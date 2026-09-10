class Api::V1::Accounts::JrcCampaigns::BlacklistsController < Api::V1::Accounts::JrcCampaigns::BaseController
  before_action :set_entry, only: :destroy

  def index
    entries = Current.account.jrc_campaign_blacklists.order(created_at: :desc)
    render json: entries.map { |entry| entry.as_json(only: [:id, :phone_number, :reason, :source, :created_at]) }
  end

  def create
    entry = Current.account.jrc_campaign_blacklists.new(blacklist_params)
    entry.created_by = Current.user
    if entry.save
      render json: entry.as_json(only: [:id, :phone_number, :reason, :source, :created_at]), status: :created
    else
      render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @entry.destroy!
    head :no_content
  end

  private

  def set_entry
    @entry = Current.account.jrc_campaign_blacklists.find(params[:id])
  end

  def blacklist_params
    params.require(:blacklist).permit(:phone_number, :reason, :source)
  end
end
