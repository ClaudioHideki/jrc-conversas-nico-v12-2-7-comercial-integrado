# Copy into the disposable HTTP runtime's initializers, never the production app.
if ENV['CONTRACT_TEST_ONLY'] == 'true'
  abort('ISOLATED_TEST_REQUIRED') unless Rails.env.test?

  # HTTP browser tests use a fixed compiled snapshot, like production. Repeatedly
  # scanning all source mtimes in the Docker Desktop filesystem blocks requests.
  Rails.application.config.enable_reloading = false
  Rails.application.config.cache_classes = true
end
