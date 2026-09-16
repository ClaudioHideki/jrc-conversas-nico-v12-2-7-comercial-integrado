require 'rails_helper'

RSpec.describe JrcBroker::Access do
  it 'keeps delegated reconnection separate from administration' do
    expect(described_class.allowed?(administrator: false, assigned: true, delegated: true, action: :pair)).to be(true)
    expect(described_class.allowed?(administrator: false, assigned: true, delegated: true, action: :disconnect)).to be(false)
    expect(described_class.allowed?(administrator: false, assigned: false, delegated: true, action: :pair)).to be(false)
    expect(described_class.allowed?(administrator: false, assigned: true, delegated: false, action: :pair)).to be(false)
    expect(described_class.allowed?(administrator: false, assigned: true, delegated: false, action: :status)).to be(true)
    expect(described_class.allowed?(administrator: true, assigned: false, delegated: false, action: :confirm_identity)).to be(true)
  end
end
