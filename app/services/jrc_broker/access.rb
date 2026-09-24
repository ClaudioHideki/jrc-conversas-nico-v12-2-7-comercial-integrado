class JrcBroker::Access
  ACTIONS = [:status, :pair, :disconnect, :manage, :confirm_identity].freeze

  def self.allowed?(administrator:, assigned:, action:, can_pair: false)
    return false unless ACTIONS.include?(action)
    return true if administrator
    return assigned if action == :status
    return assigned && can_pair if action == :pair

    false
  end
end
