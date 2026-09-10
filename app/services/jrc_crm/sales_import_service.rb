module JrcCrm
  class SalesImportService
    def initialize(account:)
      @account = account
      @counts = Hash.new(0)
    end

    def perform
      ActiveRecord::Base.transaction do
        import_pipelines
        import_stages
        import_lost_reasons
        import_deals
        import_activities
        import_stage_history
      end
      @counts.symbolize_keys
    end

    private

    def import_pipelines
      @account.sales_pipelines.find_each do |source|
        target = @account.jrc_crm_pipelines.find_or_initialize_by(legacy_sales_pipeline_id: source.id)
        target.assign_attributes(name: source.name, key: "sales-#{source.id}", active: source.active,
                                 position: source.id)
        @counts[:pipelines] += 1 if target.new_record?
        target.save!
      end
    end

    def import_stages
      @account.sales_stages.find_each do |source|
        pipeline = @account.jrc_crm_pipelines.find_by!(legacy_sales_pipeline_id: source.sales_pipeline_id)
        target = @account.jrc_crm_stages.find_or_initialize_by(legacy_sales_stage_id: source.id)
        target.assign_attributes(
          pipeline: pipeline,
          name: source.name,
          key: "sales-#{source.id}",
          position: source.position,
          color: source.color,
          probability: stage_probability(source.stage_type),
          is_terminal: source.stage_type != 'open',
          is_won: source.stage_type == 'won',
          is_lost: source.stage_type == 'lost',
          active: source.active
        )
        @counts[:stages] += 1 if target.new_record?
        target.save!
      end
    end

    def import_lost_reasons
      @account.sales_loss_reasons.find_each do |source|
        target = @account.jrc_crm_lost_reasons.find_by(legacy_sales_loss_reason_id: source.id) ||
                 @account.jrc_crm_lost_reasons.find_by(name: source.name) ||
                 @account.jrc_crm_lost_reasons.new
        target.assign_attributes(name: source.name, active: source.active, legacy_sales_loss_reason_id: source.id)
        @counts[:lost_reasons] += 1 if target.new_record?
        target.save!
      end
    end

    def import_deals
      @account.sales_opportunities.find_each do |source|
        target = @account.jrc_crm_deals.find_or_initialize_by(legacy_sales_opportunity_id: source.id)
        target.assign_attributes(deal_attributes(source))
        @counts[:deals] += 1 if target.new_record?
        target.save!
        target.link_conversation!(source.conversation, source.owner) if source.conversation
      end
    end

    def import_activities
      @account.sales_activities.find_each do |source|
        deal = @account.jrc_crm_deals.find_by!(legacy_sales_opportunity_id: source.sales_opportunity_id)
        target = @account.jrc_crm_activities.find_or_initialize_by(legacy_sales_activity_id: source.id)
        target.assign_attributes(
          deal: deal,
          contact: source.contact,
          user: source.owner,
          activity_type: source.activity_type,
          title: source.title,
          description: source.notes,
          due_at: source.scheduled_at,
          status: source.status,
          completed_at: source.completed_at,
          created_at: source.created_at,
          updated_at: source.updated_at
        )
        @counts[:activities] += 1 if target.new_record?
        target.save!
      end
    end

    def import_stage_history
      SalesStageHistory.where(account_id: @account.id).find_each do |source|
        deal = @account.jrc_crm_deals.find_by!(legacy_sales_opportunity_id: source.sales_opportunity_id)
        target = @account.jrc_crm_audit_events.find_or_initialize_by(legacy_sales_stage_history_id: source.id)
        target.assign_attributes(
          event_type: 'deal_stage_changed',
          actor_type: 'User',
          actor_id: source.user_id,
          resource_type: 'JrcCrm::Deal',
          resource_id: deal.id,
          from_value: { stage_id: crm_stage_id(source.from_stage_id) },
          to_value: { stage_id: crm_stage_id(source.to_stage_id) },
          metadata: { imported_from: 'sales_stage_histories' },
          created_at: source.changed_at
        )
        @counts[:stage_history] += 1 if target.new_record?
        target.save!
      end
    end

    def deal_attributes(source)
      {
        pipeline: @account.jrc_crm_pipelines.find_by!(legacy_sales_pipeline_id: source.sales_pipeline_id),
        stage: @account.jrc_crm_stages.find_by!(legacy_sales_stage_id: source.sales_stage_id),
        contact: source.contact,
        owner: source.owner,
        team: source.team,
        lost_reason: source.loss_reason && @account.jrc_crm_lost_reasons.find_by!(legacy_sales_loss_reason_id: source.loss_reason_id),
        title: source.title,
        description: source.notes,
        product_name: source.product_name,
        value_cents: ((source.value || 0).to_d * 100).round,
        temperature: source.temperature,
        source: source.source_channel,
        status: source.status,
        won_at: source.won_at,
        lost_at: source.lost_at,
        lost_reason_note: source.loss_notes,
        metadata: { legacy_inbox_id: source.inbox_id, legacy_archived_at: source.archived_at },
        created_at: source.created_at,
        updated_at: source.updated_at
      }
    end

    def crm_stage_id(sales_stage_id)
      return nil if sales_stage_id.blank?

      @account.jrc_crm_stages.find_by!(legacy_sales_stage_id: sales_stage_id).id
    end

    def stage_probability(stage_type)
      return 100 if stage_type == 'won'
      return 0 if stage_type == 'lost'

      50
    end
  end
end
