require 'securerandom'

module JrcCrm
  class AutomationRunnerService
    MAX_EXECUTION_DEPTH = 5

    def initialize(rule:, resource:, account:, correlation_id: nil, depth: 0, event_type: nil)
      @rule = rule
      @resource = resource
      @account = account
      @correlation_id = correlation_id.presence || SecureRandom.uuid
      @depth = depth.to_i
      @event_type = event_type.presence || @rule.trigger_type
      @execution_id = SecureRandom.uuid
    end

    def call
      raise Pundit::NotAuthorizedError unless @rule.account_id == @account.id && @resource.account_id == @account.id
      return { success: false, reason: :inactive } unless @rule.active? && @account.active? && @account.feature_enabled?('jrc_crm')

      # 1. Loop Protection: Maximum recursion depth
      if @depth >= MAX_EXECUTION_DEPTH
        record_skipped_execution("Max recursion depth of #{MAX_EXECUTION_DEPTH} reached. Execution aborted to prevent loops.")
        return { success: false, reason: :max_depth_exceeded }
      end

      # 2. Idempotency Check: Prevent duplicate execution of same rule for same correlation and event
      if duplicate_execution?
        record_skipped_execution("Idempotent skip: Rule #{@rule.id} already executed for correlation #{@correlation_id}.")
        return { success: false, reason: :duplicate_execution }
      end

      return { success: false, reason: :conditions_not_met } unless conditions_met?

      execution = create_execution_record(:running)

      begin
        ActiveRecord::Base.transaction do
          execute_actions
        end

        execution.update!(
          status: 'completed',
          finished_at: Time.current
        )

        @rule.increment!(:execution_count)
        @rule.update!(last_executed_at: Time.current)

        { success: true, execution_id: @execution_id }
      rescue StandardError => e
        execution.update!(
          status: 'failed',
          error_message: e.message,
          finished_at: Time.current
        )
        Rails.logger.error("[JrcCrm::AutomationRunner] Error in rule #{@rule.id}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        { success: false, error: e.message }
      end
    end

    private

    def duplicate_execution?
      JrcCrm::AutomationExecution.exists?(
        account_id: @account.id,
        automation_rule_id: @rule.id,
        correlation_id: @correlation_id,
        event_type: @event_type,
        status: %w[running completed]
      )
    end

    def conditions_met?
      return true if @rule.conditions.blank?
      @rule.conditions.all? { |c| evaluate_condition(c) }
    end

    def evaluate_condition(condition)
      field = condition['field']
      operator = condition['operator']
      expected = condition['value']
      allowed_fields = %w[status source temperature value_cents priority activity_type name title]
      raise ArgumentError, 'Unsupported automation condition field' unless allowed_fields.include?(field) && @resource.has_attribute?(field)

      actual = @resource[field]

      case operator.to_s.downcase
      when 'equals', 'eq'
        actual.to_s == expected.to_s
      when 'not_equal', 'neq'
        actual.to_s != expected.to_s
      when 'contains'
        actual.to_s.include?(expected.to_s)
      when 'gt'
        actual.to_f > expected.to_f
      when 'lt'
        actual.to_f < expected.to_f
      when 'is_empty'
        actual.blank?
      when 'is_not_empty'
        actual.present?
      else
        raise ArgumentError, 'Unsupported automation condition operator'
      end
    end

    def execute_actions
      raise ArgumentError, 'Automation requires actions' if @rule.actions.blank?

      (@rule.actions || []).each do |action|
        case action['type']
        when 'move_stage'
          raise ArgumentError, 'Stage change requires a deal' unless @resource.is_a?(JrcCrm::Deal)

          target_stage = @account.jrc_crm_stages.find(action.fetch('stage_id'))
          result = JrcCrm::DealPipelineService.new(
            deal: @resource,
            stage: target_stage,
            actor: nil
          ).call
          raise ArgumentError, result[:error] unless result[:success]
        when 'assign_owner'
          raise ArgumentError, 'Resource does not support ownership' unless @resource.has_attribute?(:owner_id)

          owner = @account.users.find(action.fetch('owner_id'))
          @resource.update!(owner_id: owner.id)
        when 'create_activity'
          raise ArgumentError, 'Activity requires a lead or deal' unless @resource.is_a?(JrcCrm::Lead) || @resource.is_a?(JrcCrm::Deal)

          user = @account.users.find(action['user_id'] || @resource.owner_id)
          @account.jrc_crm_activities.create!(
            deal_id: @resource.is_a?(JrcCrm::Deal) ? @resource.id : nil,
            lead_id: @resource.is_a?(JrcCrm::Lead) ? @resource.id : nil,
            user_id: user.id,
            activity_type: action['activity_type'] || 'task',
            title: action['title'] || 'Atividade Automática',
            due_at: (action['due_offset_days'] || 1).to_i.days.from_now
          )
        when 'enqueue_n8n_event'
          # Asynchronous safe dispatch - failure in n8n never affects core CRM
          JrcCrm::DispatchN8nEventJob.perform_later(
            @account.id,
            @resource.class.name,
            @resource.id,
            action['event_name'] || @event_type,
            { correlation_id: @correlation_id, depth: @depth + 1 }
          )
        else
          raise ArgumentError, 'Unsupported automation action'
        end
      end
    end

    def create_execution_record(initial_status)
      JrcCrm::AutomationExecution.create!(
        account_id: @account.id,
        automation_rule_id: @rule.id,
        execution_id: @execution_id,
        correlation_id: @correlation_id,
        event_type: @event_type,
        depth: @depth,
        status: initial_status.to_s,
        started_at: Time.current,
        metadata: {
          resource_type: @resource.class.name,
          resource_id: @resource.id
        }
      )
    end

    def record_skipped_execution(reason)
      JrcCrm::AutomationExecution.create!(
        account_id: @account.id,
        automation_rule_id: @rule.id,
        execution_id: @execution_id,
        correlation_id: @correlation_id,
        event_type: @event_type,
        depth: @depth,
        status: 'skipped_loop',
        error_message: reason,
        started_at: Time.current,
        finished_at: Time.current
      )
    end
  end
end
