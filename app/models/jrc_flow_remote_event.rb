class JrcFlowRemoteEvent < ApplicationRecord
  belongs_to :connection, class_name: 'JrcFlowConnection'
  validates :payload_ciphertext, length: { maximum: 6.megabytes }

  def payload
    JrcFlows::Secrets.decrypt(payload_ciphertext)
  end

  def payload=(value)
    self.payload_ciphertext = JrcFlows::Secrets.encrypt(value)
  end
end
