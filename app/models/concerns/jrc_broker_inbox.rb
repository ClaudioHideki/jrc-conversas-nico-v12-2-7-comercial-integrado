module JrcBrokerInbox
  extend ActiveSupport::Concern

  included do
    has_one :jrc_broker_inbox_binding, dependent: :destroy
  end

  def jrc_broker_bound?
    JrcBroker::Configuration.enabled? && account.feature_enabled?('jrc_broker') && jrc_broker_inbox_binding.present?
  end
end
