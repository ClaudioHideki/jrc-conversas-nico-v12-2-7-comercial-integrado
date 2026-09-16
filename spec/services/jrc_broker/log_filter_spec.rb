require 'rails_helper'

RSpec.describe 'JRC Broker request log filtering' do
  it 'filters the camelCase key submitted by the native setup form' do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    expect(filter.filter('controlKey' => 'synthetic-sensitive-key')).to eq('controlKey' => '[FILTERED]')
  end
end
