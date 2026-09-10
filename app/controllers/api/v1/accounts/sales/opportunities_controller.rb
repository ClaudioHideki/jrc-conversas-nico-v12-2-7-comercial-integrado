class Api::V1::Accounts::Sales::OpportunitiesController < Api::V1::Accounts::Sales::BaseController
  before_action :set_opportunity, only: [:show, :update, :move, :archive]

  def index
    authorize SalesOpportunity
    opportunities = filtered_scope.includes(
      :sales_stage, :owner, :team, :loss_reason, :inbox,
      { contact: contact_includes },
      :conversation, { sales_activities: :owner }
    ).order(updated_at: :desc)
    render json: { opportunities: opportunities.map { |opportunity| serialize_opportunity(opportunity) } }
  end

  def show
    authorize @opportunity
    @opportunity = opportunity_scope.includes(
      :sales_stage, :owner, :team, :loss_reason, :inbox,
      { contact: contact_includes },
      :conversation, { sales_activities: :owner },
      { sales_stage_histories: [:from_stage, :to_stage, :user] }
    ).find(@opportunity.id)
    render json: serialize_opportunity(@opportunity, details: true)
  end

  def create
    authorize SalesOpportunity
    existing = Current.account.sales_opportunities.find_by(idempotency_key: opportunity_params[:idempotency_key])
    return render json: serialize_opportunity(existing), status: :ok if existing

    pipeline = Sales::DefaultPipelineService.new(Current.account).perform
    contact = Current.account.contacts.find(opportunity_params[:contact_id])
    conversation = fetch_conversation(contact)
    owner = permitted_owner(conversation)
    stage = pipeline.sales_stages.find_by!(stage_type: 'open', position: 1)
    opportunity = ActiveRecord::Base.transaction do
      record = Current.account.sales_opportunities.new(
        opportunity_params.except(:owner_id, :conversation_id, :conversation_display_id, :team_id)
      )
      record.assign_attributes(
        sales_pipeline: pipeline,
        sales_stage: stage,
        contact: contact,
        conversation: conversation,
        inbox: conversation&.inbox,
        team: permitted_team(conversation),
        owner: owner,
        source_channel: record.source_channel.presence || conversation&.inbox&.channel_type
      )
      record.save!
      record.sales_stage_histories.create!(account: Current.account, to_stage: stage, user: Current.user, changed_at: Time.current)
      record
    end
    render json: serialize_opportunity(opportunity.reload), status: :created
  rescue ActiveRecord::RecordNotUnique
    existing = Current.account.sales_opportunities.find_by!(idempotency_key: opportunity_params[:idempotency_key])
    render json: serialize_opportunity(existing), status: :ok
  end

  def update
    authorize @opportunity
    attributes = opportunity_params.except(
      :contact_id, :conversation_id, :conversation_display_id, :idempotency_key, :owner_id, :team_id
    )
    if Current.account_user.administrator?
      attributes[:owner] = Current.account.users.find(opportunity_params[:owner_id]) if opportunity_params[:owner_id].present?
      attributes[:team] = if opportunity_params[:team_id].present?
                            Current.account.teams.find(opportunity_params[:team_id])
                          end
    end
    @opportunity.update!(attributes)
    render json: serialize_opportunity(@opportunity.reload)
  end

  def move
    authorize @opportunity, :move?
    stage = Current.account.sales_stages.find(move_params[:stage_id])
    loss_reason = Current.account.sales_loss_reasons.find(move_params[:loss_reason_id]) if move_params[:loss_reason_id].present?
    Sales::MoveOpportunityService.new(
      opportunity: @opportunity,
      stage: stage,
      user: Current.user,
      loss_reason: loss_reason,
      loss_notes: move_params[:loss_notes]
    ).perform
    render json: serialize_opportunity(@opportunity.reload)
  end

  def archive
    authorize @opportunity, :archive?
    @opportunity.update!(status: 'archived', archived_at: Time.current)
    render json: serialize_opportunity(@opportunity)
  end

  private

  def set_opportunity
    @opportunity = opportunity_scope.find(params[:id])
  end

  def contact_includes
    includes = [{ avatar_attachment: :blob }]
    includes.unshift(:company) if Contact.reflect_on_association(:company)
    includes
  end

  def filtered_scope
    scope = opportunity_scope.active
    if params[:q].present?
      query = "%#{SalesOpportunity.sanitize_sql_like(params[:q])}%"
      scope = scope.joins(:contact).where(
        'sales_opportunities.title ILIKE :query OR sales_opportunities.product_name ILIKE :query OR contacts.name ILIKE :query OR contacts.email ILIKE :query OR contacts.phone_number ILIKE :query OR contacts.identifier ILIKE :query',
        query: query
      )
    end
    scope = scope.where(owner_id: params[:owner_id]) if params[:owner_id].present?
    scope = scope.where(team_id: params[:team_id]) if params[:team_id].present?
    scope = scope.where(sales_stage_id: params[:stage_id]) if params[:stage_id].present?
    scope = scope.where(source_channel: params[:channel]) if params[:channel].present?
    scope = scope.where(temperature: params[:temperature]) if params[:temperature].present?
    scope = scope.where(status: params[:status]) if params[:status].present?
    if params[:product].present?
      product = SalesOpportunity.sanitize_sql_like(params[:product])
      scope = scope.where('sales_opportunities.product_name ILIKE ?', "%#{product}%")
    end
    scope = scope.where(created_at: Time.zone.parse(params[:from]).beginning_of_day..) if params[:from].present?
    scope = scope.where(created_at: ..Time.zone.parse(params[:to]).end_of_day) if params[:to].present?
    scope
  end

  def fetch_conversation(contact)
    return if opportunity_params[:conversation_id].blank? && opportunity_params[:conversation_display_id].blank?

    conversation = if opportunity_params[:conversation_display_id].present?
                     Current.account.conversations.find_by!(display_id: opportunity_params[:conversation_display_id])
                   else
                     Current.account.conversations.find(opportunity_params[:conversation_id])
                   end
    authorize conversation, :show?
    raise ActiveRecord::RecordNotFound if conversation.contact_id != contact.id

    conversation
  end

  def permitted_owner(conversation)
    return Current.account.users.find(opportunity_params[:owner_id]) if Current.account_user.administrator? && opportunity_params[:owner_id].present?
    return conversation.assignee if Current.account_user.administrator? && conversation&.assignee

    Current.user
  end

  def permitted_team(conversation)
    return conversation&.team unless Current.account_user.administrator? && opportunity_params[:team_id].present?

    Current.account.teams.find(opportunity_params[:team_id])
  end

  def opportunity_params
    params.require(:opportunity).permit(
      :contact_id, :conversation_id, :conversation_display_id, :owner_id, :team_id, :title, :product_name,
      :value, :temperature, :source_channel, :notes, :idempotency_key
    )
  end

  def move_params
    params.require(:opportunity).permit(:stage_id, :loss_reason_id, :loss_notes)
  end
end
