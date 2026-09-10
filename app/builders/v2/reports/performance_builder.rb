class V2::Reports::PerformanceBuilder
  METRICS = %w[conversations_count resolutions_count avg_first_response_time reply_time].freeze

  pattr_initialize [:account!, :user, :params!]

  def build
    {
      scope: user.present? ? 'agent' : 'account',
      subject: subject,
      summary: current_summary.merge(previous: previous_summary),
      queue: queue_metrics,
      series: series,
      csat: csat_metrics,
      sla: sla_metrics,
      team: team_metrics
    }
  end

  private

  def subject
    return { id: account.id, name: account.name } if user.blank?

    account_user = account.account_users.find_by(user_id: user.id)
    {
      id: user.id,
      name: user.name,
      avatar_url: user.avatar_url,
      availability: account_user&.availability_status
    }
  end

  def current_summary
    metric_builder(current_range).summary
  end

  def previous_summary
    metric_builder(previous_range).summary
  end

  def metric_builder(selected_range)
    V2::Reports::Conversations::MetricBuilder.new(account, report_params(selected_range))
  end

  def series
    METRICS.index_with do |metric|
      V2::Reports::Conversations::ReportBuilder.new(
        account,
        report_params(current_range).merge(metric: metric)
      ).timeseries
    end
  end

  def report_params(selected_range)
    {
      type: user.present? ? :agent : :account,
      id: user&.id,
      since: selected_range.begin.to_i,
      until: selected_range.end.to_i,
      group_by: params[:group_by].presence || 'day',
      timezone_offset: params[:timezone_offset],
      business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours])
    }
  end

  def queue_metrics
    open_scope = conversation_scope.open
    {
      open: open_scope.count,
      awaiting_reply: open_scope.where.not(waiting_since: nil).count,
      unattended: open_scope.unattended.count,
      pending: conversation_scope.pending.count,
      waiting_over_30_minutes: open_scope.where('waiting_since < ?', 30.minutes.ago).count
    }
  end

  def csat_metrics
    responses = account.csat_survey_responses.where(created_at: current_range)
    responses = responses.where(assigned_agent_id: user.id) if user.present?
    recent_feedback = responses.where.not(feedback_message: [nil, ''])
                               .includes(:contact)
                               .order(created_at: :desc)
                               .limit(2)

    {
      average: responses.average(:rating)&.round(2),
      count: responses.count,
      feedback: recent_feedback.map do |response|
        {
          rating: response.rating,
          message: response.feedback_message,
          contact_name: response.contact.name,
          created_at: response.created_at
        }
      end
    }
  end

  def sla_metrics
    return { available: false, hit_rate: nil, total: 0, misses: 0 } unless account.respond_to?(:applied_slas)

    applied_slas = account.applied_slas.joins(:conversation).where(applied_slas: { created_at: current_range })
    applied_slas = applied_slas.where(conversations: { assignee_id: user.id }) if user.present?
    total = applied_slas.count
    misses = applied_slas.missed.count

    {
      available: true,
      hit_rate: total.positive? ? (((total - misses) / total.to_f) * 100).round(2) : nil,
      total: total,
      misses: misses
    }
  end

  def team_metrics
    return [] if user.present?

    summaries = V2::Reports::AgentSummaryBuilder.new(
      account: account,
      params: report_params(current_range)
    ).build
    users = account.users.where(id: summaries.pluck(:id)).index_by(&:id)
    agent_ids = account.account_users.agent.pluck(:user_id)

    summaries.filter_map do |metrics|
      next unless agent_ids.include?(metrics[:id])

      agent = users[metrics[:id]]
      next if agent.blank?

      metrics.merge(name: agent.name, avatar_url: agent.avatar_url)
    end.sort_by { |metrics| -metrics[:resolved_conversations_count].to_i }.first(8)
  end

  def conversation_scope
    scope = account.conversations
    user.present? ? scope.where(assignee_id: user.id) : scope
  end

  def current_range
    @current_range ||= Time.zone.at(params[:since].to_i)..Time.zone.at(params[:until].to_i)
  end

  def previous_range
    @previous_range ||= begin
      duration = current_range.end - current_range.begin
      (current_range.begin - duration)..current_range.begin
    end
  end
end
