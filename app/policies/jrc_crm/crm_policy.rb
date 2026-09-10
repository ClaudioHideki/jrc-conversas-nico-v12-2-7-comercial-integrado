module JrcCrm
  class CrmPolicy < ApplicationPolicy
    def admin?
      account_user&.administrator?
    end

    def crm_agent?
      user.present? && account.present?
    end

    def same_account?
      !record.respond_to?(:account_id) || record.account_id == account.id
    end

    def owns_record?
      record.respond_to?(:owner_id) && record.owner_id == user.id
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        account_scope = scope.where(account_id: account.id)
        return account_scope if account_user&.administrator?

        account_scope.where(owner_id: user.id)
      end
    end
  end
end
