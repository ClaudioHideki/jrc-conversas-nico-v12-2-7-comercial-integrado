require 'rails_helper'

RSpec.describe JrcBroker::Access do
  it 'allows inbox members to reconnect while keeping administrative actions restricted' do
    expect(described_class.allowed?(administrator: false, assigned: true, action: :pair)).to be(true)
    expect(described_class.allowed?(administrator: false, assigned: true, action: :disconnect)).to be(false)
    expect(described_class.allowed?(administrator: false, assigned: false, action: :pair)).to be(false)
    expect(described_class.allowed?(administrator: false, assigned: true, action: :status)).to be(true)
    expect(described_class.allowed?(administrator: true, assigned: false, action: :confirm_identity)).to be(true)
  end
end
