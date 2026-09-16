class JrcBroker::Grants
  def self.list(account:, inbox:)
    inbox.members.joins(:account_users).where(account_users: { account_id: account.id }).select(:id, :name).distinct.map do |user|
      { user_id: user.id, name: user.name,
        can_pair: JrcBrokerInboxGrant.exists?(account_id: account.id, inbox_id: inbox.id, user_id: user.id, can_pair: true) }
    end
  end

  def self.update!(account:, inbox:, user_ids:)
    validate_ids!(user_ids)
    ids = user_ids

    inbox.with_lock do
      available = inbox.members.joins(:account_users).where(account_users: { account_id: account.id }).distinct.pluck(:id)
      raise JrcBroker::Client::Error.new('JRC_BROKER_FORBIDDEN', status: 403) unless (ids - available).empty?

      grants = JrcBrokerInboxGrant.where(account_id: account.id, inbox_id: inbox.id)
      grants.where.not(user_id: ids).destroy_all
      ids.each { |id| grants.find_or_initialize_by(user_id: id).update!(can_pair: true) }
    end
    list(account: account, inbox: inbox)
  end

  def self.validate_ids!(ids)
    return if ids.is_a?(Array) && ids.length <= 100 && ids.all? { |id| id.is_a?(Integer) && id.positive? } && ids.uniq == ids

    raise JrcBroker::Client::Error.new('JRC_BROKER_INVALID_REQUEST', status: 400)
  end
end
