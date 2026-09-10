require 'uri'

class JrcCampaigns::ProviderMessageProxy
  AttachmentProxy = Data.define(:file_type, :download_url, :meta, :file)

  class FileProxy
    attr_reader :filename

    def initialize(filename)
      @filename = filename.to_s
    end

    def attached?
      false
    end
  end

  attr_accessor :external_error, :status
  attr_reader :content_type, :content_attributes

  def initialize(kind:, body:, media_url: nil, file_name: nil)
    @kind = kind
    @body = body
    @media_url = media_url
    @file_name = file_name
    @content_type = 'text'
    @content_attributes = {}
  end

  def attachments
    return [] unless %w[image document video audio].include?(@kind)

    [AttachmentProxy.new(
      file_type: @kind,
      download_url: @media_url,
      meta: {},
      file: FileProxy.new(@file_name.presence || fallback_file_name)
    )]
  end

  def outgoing_content
    @body.to_s
  end

  def save!
    true
  end

  private

  def fallback_file_name
    File.basename(URI.parse(@media_url.to_s).path)
  rescue URI::InvalidURIError
    'arquivo'
  end
end
