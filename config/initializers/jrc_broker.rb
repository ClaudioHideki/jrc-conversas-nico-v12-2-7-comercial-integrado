Rails.application.config.to_prepare do
  JrcBroker::Configuration.credential_store if JrcBroker::Configuration.enabled?
end
