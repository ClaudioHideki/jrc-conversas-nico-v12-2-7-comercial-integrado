# Runs the pilot's behavior tests without filesystem hot-reload on Windows binds.
# Authentication, SQL transactions, callbacks and policies remain enabled.
ENV['RAILS_ENV'] = 'test'
require_relative '../config/application'
Rails.application.config.before_initialize do
  Rails.application.config.enable_reloading = false
  Rails.application.config.action_dispatch.show_exceptions = :none
end
require 'rspec/core'
exit RSpec::Core::Runner.run(ARGV)
