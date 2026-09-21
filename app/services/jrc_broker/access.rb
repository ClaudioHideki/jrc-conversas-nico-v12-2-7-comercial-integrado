class JrcBroker::Access
  ACTIONS = [:status, :pair, :disconnect, :manage, :confirm_identity].freeze

  def self.allowed?(administrator:, assigned:, action:)
    return false unless ACTIONS.include?(action)
    return true if administrator
    return assigned if [:status, :pair].include?(action)

    false
  end
end
