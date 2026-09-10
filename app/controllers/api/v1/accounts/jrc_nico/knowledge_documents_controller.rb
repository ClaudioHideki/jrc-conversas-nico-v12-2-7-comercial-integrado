class Api::V1::Accounts::JrcNico::KnowledgeDocumentsController < Api::V1::Accounts::BaseController
  before_action :ensure_administrator
  before_action :set_document, only: [:update, :approve]

  def index
    render json: scope.order(updated_at: :desc).limit(100).map { |document| snapshot(document) }
  end

  def create
    document = scope.create!(document_params.merge(author: Current.user))
    render json: snapshot(document), status: :created
  end

  def update
    @document.with_lock do
      @document.update!(document_params.merge(approved_at: nil, approved_by: nil))
    end
    render json: snapshot(@document)
  end

  def approve
    accepted = @document.with_lock do
      next false unless params[:digest] == @document.digest

      @document.update!(approved_at: Time.current, approved_by: Current.user)
      true
    end
    render json: accepted ? snapshot(@document) : { error: 'document_changed' }, status: accepted ? :ok : :conflict
  end

  private

  def scope
    JrcNico::KnowledgeDocument.where(account: Current.account)
  end

  def ensure_administrator
    return if Current.account_user&.administrator? && Current.account.custom_attributes['nico_enabled'] == true

    render json: { error: 'administrator_required' }, status: :forbidden
  end

  def set_document
    @document = scope.find(params[:id])
  end

  def document_params
    params.permit(:title, :body, :customer_visible)
  end

  def snapshot(document)
    document.as_json(only: [:id, :title, :body, :customer_visible, :author_id, :approved_by_id, :approved_at, :updated_at]).merge(digest: document.digest)
  end
end
