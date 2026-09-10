class Api::V1::Accounts::JrcCampaigns::MetadataController < Api::V1::Accounts::JrcCampaigns::BaseController
  def show
    render json: {
      account_name: Current.account.name,
      contacts_count: Current.account.contacts.where.not(phone_number: [nil, '']).count,
      source_inboxes: source_inboxes,
      labels: Current.account.labels.order(:title).map { |label| { id: label.id, title: label.title, color: label.color } },
      inboxes: whatsapp_inboxes,
      pipelines: pipelines,
      sanitized_lists: Current.account.jrc_campaign_sanitized_lists.order(created_at: :desc).map { |list| sanitized_list_json(list) },
      blacklist_count: Current.account.jrc_campaign_blacklists.count
    }
  end

  private

  def source_inboxes
    Current.account.inboxes.order(:name).map do |inbox|
      { id: inbox.id, name: inbox.name, channel_type: inbox.channel_type }
    end
  end

  def whatsapp_inboxes
    Current.account.inboxes.includes(:channel).filter_map do |inbox|
      next unless inbox.channel_type == 'Channel::Whatsapp'

      channel = inbox.channel
      {
        id: inbox.id,
        name: inbox.name,
        phone_number: channel.phone_number,
        provider: channel.provider,
        health_status: channel.phone_number_health.to_h['status'],
        health_error: channel.phone_number_health_error.present?,
        health_checked_at: channel.phone_number_health_checked_at,
        templates: Array(channel.message_templates).select { |template| template['status'].to_s.casecmp('approved').zero? }
      }
    end
  end

  def pipelines
    Current.account.jrc_crm_pipelines.includes(:stages).order(:position).map do |pipeline|
      {
        id: pipeline.id,
        name: pipeline.name,
        stages: pipeline.stages.select(&:active?).map { |stage| { id: stage.id, name: stage.name, color: stage.color, position: stage.position } }
      }
    end
  end

  def sanitized_list_json(list)
    { id: list.id, name: list.name, stats: list.stats, created_at: list.created_at }
  end
end
