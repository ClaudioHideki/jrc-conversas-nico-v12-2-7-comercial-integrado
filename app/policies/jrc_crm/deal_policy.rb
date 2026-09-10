module JrcCrm
  class DealPolicy < CrmPolicy
    def index?
      crm_agent?
    end

    def show?
      crm_agent? && same_account? && (admin? || owns_record?)
    end

    def create?
      crm_agent?
    end

    def update?
      show?
    end

    def destroy?
      admin?
    end

    def move_stage?
      same_account? && (admin? || owns_record?)
    end

    def win?
      move_stage?
    end

    def lose?
      move_stage?
    end
  end
end
