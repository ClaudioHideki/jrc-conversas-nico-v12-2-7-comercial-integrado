class Api::V1::Accounts::JrcCampaigns::MediaAssetsController < Api::V1::Accounts::JrcCampaigns::BaseController
  include Rails.application.routes.url_helpers

  def create
    asset = JrcCampaigns::MediaAsset.new(account: Current.account, created_by: Current.user, kind: params[:kind])
    asset.file.attach(params.require(:file))
    asset.save!
    render json: {
      id: asset.id,
      url: rails_blob_url(asset.file, host: request.base_url),
      file_name: asset.file.filename.to_s,
      content_type: asset.file.content_type,
      byte_size: asset.file.byte_size
    }, status: :created
  end
end
