class SalesOpportunityPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      account_scope = scope.where(account_id: account.id)
      return account_scope if account_user.administrator?

      team_ids = user.teams.where(account_id: account.id).select(:id)
      account_scope.where(owner_id: user.id).or(account_scope.where(team_id: team_ids))
    end
  end

  def index?
    true
  end

  def show?
    scope.exists?(id: record.id)
  end

  def create?
    true
  end

  def update?
    scope.exists?(id: record.id)
  end

  def move?
    update?
  end

  def archive?
    update?
  end
end
