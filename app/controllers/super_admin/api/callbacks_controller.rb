class SuperAdmin::Api::CallbacksController < Api::V1::Accounts::CallbacksController
  skip_before_action :authenticate_user!
  skip_before_action :current_account
  skip_before_action :validate_token_api_access

  before_action :authenticate_super_admin!
  before_action :set_super_admin_current_context

  def register_facebook_page
    super
    render 'api/v1/accounts/callbacks/register_facebook_page' unless performed?
  end

  def facebook_pages
    super
    render 'api/v1/accounts/callbacks/facebook_pages' unless performed?
  end

  def reauthorize_page
    if @inbox&.facebook?
      fb_page_id = @inbox.channel.page_id
      page_details = fb_object.get_connections('me', 'accounts')

      if (page_detail = (page_details || []).detect { |page| fb_page_id == page['id'] })
        update_fb_page(fb_page_id, page_detail['access_token'])
        render 'api/v1/accounts/callbacks/reauthorize_page' and return
      end
    end

    head :unprocessable_entity
  end

  private

  def set_super_admin_current_context
    Current.user = current_super_admin
    Current.account = Account.find(params[:account_id])
    Current.account_user = nil
  end

  def inbox
    @inbox = Current.account.inboxes.find_by(id: params[:inbox_id])
  end

  def log_additional_info
    Rails.logger.debug do
      "facebook_page_registration_failed account_id=#{Current.account.id} page_id=#{params[:page_id]} inbox_name=#{params[:inbox_name]}"
    end
  end
end
