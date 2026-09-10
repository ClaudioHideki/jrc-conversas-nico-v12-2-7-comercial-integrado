# frozen_string_literal: true

if Rails.env.development? && ENV['DISABLE_MINI_PROFILER'].blank?
  begin
    require 'rack/files'
  rescue LoadError
    require 'rack/file'
  end
  require 'rack-mini-profiler'

  Rack.const_set(:File, Rack::Files) if defined?(Rack::Files) && !Rack.const_defined?(:File)

  # initialization is skipped so trigger it
  Rack::MiniProfilerRails.initialize!(Rails.application)
end
