class Api::V1::Accounts::JrcNico::ProposalsController < Api::V1::Accounts::BaseController
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ArgumentError, ActiveRecord::RecordInvalid, with: :invalid

  def create
    run = JrcNico::Run.where(account: Current.account, user: Current.user).find(params[:run_id])
    access = authorize_run(run)
    lead = access.leads.find_by(id: params[:lead_id])
    references = Array(run.result['evidence']).map { |item| item['reference'] if item['source'] == 'crm' }
    raise ArgumentError unless lead && references.include?("lead:#{lead.id}")

    title = params[:title].to_s.strip
    due_at = Time.iso8601(params[:due_at].to_s)
    raise ArgumentError unless title.length.between?(1, 200) && due_at > Time.current && due_at < 1.year.from_now

    action = params[:action_kind].presence || 'follow_up'
    raise ArgumentError unless JrcNico::AgentCatalog.fetch(run.agent_key)[:actions].include?(action)

    payload = { 'lead_id' => lead.id, 'title' => title, 'due_at' => due_at.utc.iso8601,
                'action_kind' => action, 'activity_type' => action == 'follow_up' ? 'follow_up' : 'task' }
    if action == 'create_deal'
      pipeline = Current.account.jrc_crm_pipelines.active.order(:position).first
      stage = pipeline&.stages&.where(active: true, is_terminal: false)&.first
      raise ArgumentError unless stage

      payload.merge!('pipeline_id' => pipeline.id, 'stage_id' => stage.id, 'value_cents' => 0)
    end
    digest = Digest::SHA256.hexdigest([run.id, payload].to_json)
    proposal = nil
    Current.account.with_lock do
      proposal = scope.find_by(request_id: params[:request_id])
      if proposal && proposal.digest != digest
        render json: { error: 'idempotency_conflict' }, status: :conflict
        return
      end
      proposal ||= scope.create!(account: Current.account, user: Current.user, run: run, request_id: params[:request_id],
                                 payload: payload, digest: digest, expires_at: 24.hours.from_now)
    end
    render json: proposal.snapshot, status: :created
  rescue Pundit::NotAuthorizedError
    forbidden
  end

  def approve
    proposal = scope.find(params[:id])
    proposal.with_lock do
      access = authorize_run(proposal.run)
      lead = access.leads.find_by(id: proposal.payload['lead_id'])
      raise Pundit::NotAuthorizedError unless lead

      if proposal.digest != params[:digest] || (proposal.status == 'pending' && (proposal.expires_at <= Time.current || Time.iso8601(proposal.payload['due_at']) <= Time.current))
        render json: { error: 'review_expired_or_changed' }, status: :conflict
        return
      end
      if proposal.status == 'pending'
        action = proposal.payload.fetch('action_kind', 'follow_up')
        raise ArgumentError unless JrcNico::AgentCatalog.fetch(proposal.run.agent_key)[:actions].include?(action)

        deal = create_deal(proposal, lead) if action == 'create_deal'
        activity = JrcCrm::Activity.create!(account: Current.account, user: Current.user, lead: lead, contact: lead.contact,
                                           deal: deal,
                                           conversation: proposal.run.conversation, title: proposal.payload['title'],
                                           due_at: proposal.payload['due_at'], activity_type: proposal.payload.fetch('activity_type', 'follow_up'), status: 'scheduled',
                                           metadata: { nico_proposal_id: proposal.id, nico_run_id: proposal.run_id, agent_key: proposal.run.agent_key, human_approved: true })
        proposal.update!(activity: activity, status: 'executed', approved_at: Time.current)
      end
    end
    render json: proposal.snapshot
  rescue Pundit::NotAuthorizedError
    forbidden
  end

  private

  def create_deal(proposal, lead)
    pipeline = Current.account.jrc_crm_pipelines.active.find_by(id: proposal.payload['pipeline_id'])
    stage = pipeline&.stages&.find_by(id: proposal.payload['stage_id'], active: true, is_terminal: false)
    raise ArgumentError unless stage

    deal = JrcCrm::Deal.create!(account: Current.account, owner: Current.user, lead: lead, contact: lead.contact,
                               pipeline: pipeline, stage: stage, title: proposal.payload['title'], value_cents: 0,
                               expected_close_at: proposal.payload['due_at'], conversion_key: "nico-proposal:#{proposal.id}",
                               metadata: { nico_proposal_id: proposal.id, human_approved: true, value_pending: true })
    deal.link_conversation!(proposal.run.conversation, Current.user)
    deal
  end

  def scope
    JrcNico::Proposal.where(account: Current.account, user: Current.user)
  end

  def authorize_run(run)
    access = JrcNico::Access.new(account: Current.account, user: Current.user, conversation: run.conversation).authorize!
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('jrc_crm')
    raise ArgumentError unless run.status == 'completed'
    raise Pundit::NotAuthorizedError unless JrcNico::ResultAccess.allowed?(run)
    raise Pundit::NotAuthorizedError unless JrcNico::AgentCatalog.for_account(Current.account).any? { |agent| agent[:key] == run.agent_key }

    access
  end

  def forbidden
    render json: { error: 'action_forbidden' }, status: :forbidden
  end

  def invalid
    render json: { error: 'invalid_proposal' }, status: :unprocessable_entity
  end
end
