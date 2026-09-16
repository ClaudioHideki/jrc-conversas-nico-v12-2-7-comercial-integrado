class JrcBroker::Access
  ACTIONS = [:status, :pair, :disconnect, :manage, :confirm_identity].freeze

  def self.allowed?(administrator:, assigned:, delegated:, action:)
    return false unless ACTIONS.include?(action)
    return true if administrator
    return assigned if action == :status

    action == :pair && assigned && delegated
  end
end
