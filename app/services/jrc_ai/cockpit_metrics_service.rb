module JrcAi
  class CockpitMetricsService
    WAITING_ALERT_MINUTES = 10
    SLA_RISK_MINUTES = 8

    def initialize(account:, user:, account_user:, period: 'today')
      @account = account
      @user = user
      @account_user = account_user
      @period = period.to_s
    end

    def perform
      {
        profile: administrator? ? 'supervisor' : 'agent',
        generated_at: Time.current.iso8601,
        period: period,
        summary: summary,
        attention: attention_items,
        channel_distribution: channel_distribution,
        daily_volume: daily_volume,
        team: team_summary,
        ai_agents: ai_agents,
        usage: usage_summary
      }
    end

    private

    attr_reader :account, :user, :account_user, :period

    def administrator?
      account_user&.administrator?
    end

    def conversation_scope
      @conversation_scope ||= begin
        scope = account.conversations
        administrator? ? scope : scope.where(assignee_id: user.id)
      end
    end

    def activity_scope
      return JrcCrm::Activity.none unless crm_allowed?

      @activity_scope ||= begin
        scope = account.jrc_crm_activities
        administrator? ? scope : scope.where(user_id: user.id)
      end
    end

    def lead_scope
      return JrcCrm::Lead.none unless crm_allowed?

      @lead_scope ||= begin
        scope = account.jrc_crm_leads
        administrator? ? scope : scope.where(owner_id: user.id)
      end
    end

    def deal_scope
      return JrcCrm::Deal.none unless crm_allowed?

      @deal_scope ||= begin
        scope = account.jrc_crm_deals
        administrator? ? scope : scope.where(owner_id: user.id)
      end
    end

    def period_range
      case period
      when '7_days'
        6.days.ago.beginning_of_day..Time.current.end_of_day
      when '30_days'
        29.days.ago.beginning_of_day..Time.current.end_of_day
      else
        Time.current.all_day
      end
    end

    def open_conversations
      conversation_scope.where(status: %w[open pending])
    end

    def waiting_conversations
      open_conversations.where.not(waiting_since: nil)
    end

    def waiting_over(minutes)
      waiting_conversations.where('waiting_since < ?', minutes.minutes.ago)
    end

    def pending_activities
      activity_scope.pending
    end

    def email_inbox_ids
      @email_inbox_ids ||= account.inboxes.where(channel_type: 'Channel::Email').pluck(:id)
    end

    def whatsapp_inbox_ids
      @whatsapp_inbox_ids ||= account.inboxes.where(channel_type: ['Channel::Whatsapp', 'Channel::TwilioSms']).pluck(:id)
    end

    def summary
      avg_response = average_seconds(
        conversation_scope.where(first_reply_created_at: period_range),
        'EXTRACT(EPOCH FROM (first_reply_created_at - created_at))'
      )
      avg_resolution = average_seconds(
        conversation_scope.where(status: 'resolved', updated_at: period_range),
        'EXTRACT(EPOCH FROM (updated_at - created_at))'
      )

      {
        conversations_open: open_conversations.count,
        conversations_waiting: waiting_conversations.count,
        emails_open: email_inbox_ids.empty? ? 0 : open_conversations.where(inbox_id: email_inbox_ids).count,
        active_channels: account.inboxes.count,
        email_channels: email_inbox_ids.count,
        whatsapp_channels: whatsapp_inbox_ids.count,
        unassigned_conversations: administrator? ? open_conversations.where(assignee_id: nil).count : 0,
        calls_in_progress: nil,
        whatsapp_calls: nil,
        missed_calls: nil,
        pending_tasks: pending_activities.count,
        overdue_returns: pending_activities.where(activity_type: %w[follow_up call]).where('due_at < ?', Time.current).count,
        appointments_today: pending_activities.where(due_at: Time.current.all_day).count,
        sla_estimated_percent: estimated_sla_percent,
        sla_risk_count: waiting_over(SLA_RISK_MINUTES).count,
        average_first_response_seconds: avg_response,
        average_resolution_seconds: avg_resolution,
        csat_percent: csat_percent,
        active_leads: lead_scope.active.count,
        open_deals: deal_scope.open_deals.count,
        online_agents: account.account_users.online.count,
        total_agents: account.account_users.count
      }
    end

    def estimated_sla_percent
      total = open_conversations.count
      return 100 if total.zero?

      risk = waiting_over(SLA_RISK_MINUTES).count
      [[((total - risk).to_f / total * 100).round, 0].max, 100].min
    end

    def csat_percent
      scope = account.csat_survey_responses.where(created_at: period_range)
      scope = scope.where(assigned_agent_id: user.id) unless administrator?
      average = scope.average(:rating)
      average.present? ? ((average.to_f / 5.0) * 100).round : nil
    rescue StandardError
      nil
    end

    def average_seconds(scope, expression)
      value = scope.pick(Arel.sql("AVG(#{expression})"))
      value.present? ? value.to_f.round : nil
    rescue StandardError
      nil
    end

    def attention_items
      items = []
      waiting_count = waiting_over(WAITING_ALERT_MINUTES).count
      overdue_count = pending_activities.overdue.count
      high_priority_count = open_conversations.where(priority: %w[high urgent]).count
      unassigned_count = administrator? ? open_conversations.where(assignee_id: nil).count : 0
      stagnant_deals = deal_scope.open_deals.where('updated_at < ?', 7.days.ago).count

      items << attention('waiting', 'Clientes aguardando', waiting_count, 'Ha atendimentos aguardando ha mais de 10 minutos.', 'home', 'high') if waiting_count.positive?
      items << attention('overdue', 'Retornos e tarefas vencidos', overdue_count, 'Compromissos precisam ser reorganizados.', 'crm_activities', 'high') if overdue_count.positive?
      items << attention('priority', 'Conversas de alta prioridade', high_priority_count, 'Atendimentos marcados como alta prioridade ou urgentes.', 'home', 'medium') if high_priority_count.positive?
      items << attention('unassigned', 'Atendimentos sem responsavel', unassigned_count, 'Distribua os atendimentos para a equipe.', 'conversation_unattended', 'medium') if unassigned_count.positive?
      items << attention('stagnant', 'Negocios sem atualizacao', stagnant_deals, 'Negocios abertos sem atualizacao ha mais de 7 dias.', 'crm_deals', 'medium') if stagnant_deals.positive?

      items.presence || [attention('ok', 'Operacao sob controle', 0, 'Nenhum alerta critico foi identificado agora.', 'jrc_cockpit', 'low')]
    end

    def attention(key, title, count, description, route_name, severity)
      { key: key, title: title, count: count, description: description, route_name: route_name, severity: severity }
    end

    def channel_distribution
      rows = open_conversations.joins(:inbox).group('inboxes.channel_type').count
      labels = {
        'Channel::Whatsapp' => 'WhatsApp',
        'Channel::Email' => 'E-mail',
        'Channel::Instagram' => 'Instagram',
        'Channel::FacebookPage' => 'Facebook',
        'Channel::WebWidget' => 'Chat do site',
        'Channel::Telegram' => 'Telegram',
        'Channel::TwilioSms' => 'SMS/WhatsApp'
      }
      rows.map do |channel_type, count|
        { channel: labels[channel_type] || channel_type.to_s.sub('Channel::', ''), count: count }
      end.sort_by { |item| -item[:count] }
    end

    def daily_volume
      start_date = 6.days.ago.to_date
      values = conversation_scope.where(created_at: start_date.beginning_of_day..Time.current)
                                 .group(Arel.sql('DATE(created_at)')).count
      (start_date..Time.current.to_date).map do |date|
        { date: date.iso8601, conversations: values[date] || values[date.to_s] || 0 }
      end
    end

    def team_summary
      return { online: account_user&.online? ? 1 : 0, busy: account_user&.busy? ? 1 : 0, offline: account_user&.offline? ? 1 : 0 } unless administrator?

      account.account_users.group(:availability).count.transform_keys(&:to_s)
    end

    def crm_allowed?
      account.feature_enabled?('jrc_crm') && (administrator? || account_user&.crm_enabled?)
    end

    def ai_agents
      return [] unless account.custom_attributes['nico_enabled'] == true

      JrcNico::AgentCatalog.for_account(account).map do |agent|
        run = JrcNico::Run.where(account: account, user: user, agent_key: agent[:key], conversation_id: conversation_scope.select(:id)).order(id: :desc).first
        agent.merge(status: run&.status || 'not_run', last_result: run ? "Última execução: #{run.status}" : 'Nenhuma análise executada.',
                    analyzed_at: run&.finished_at&.iso8601)
      end
    end
    def usage_summary
      events = account.jrc_ai_usage_events.current_month
      {
        tokens_today: account.jrc_ai_usage_events.today.sum(:total_tokens),
        tokens_month: events.sum(:total_tokens),
        estimated_cost_cents_month: events.where("metadata @> ?", { cost_available: false }.to_json).exists? ? nil : events.sum(:estimated_cost_cents),
        providers_configured: account.jrc_ai_providers.enabled.count(&:api_key_configured?)
      }
    rescue StandardError
      { tokens_today: nil, tokens_month: nil, estimated_cost_cents_month: nil, providers_configured: nil }
    end
  end
end
