require 'rails_helper'

RSpec.describe JrcNico::ErpContext do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }
  let(:binding) do
    JrcNico::ErpBinding.create!(account: account, contact: conversation.contact, verified_by: admin, cnpj: '11222333000181',
                              customer_name: 'Fictício', bemtevi_customer_id: '900001', helpdesk_company_id: '900002', mode: 'fixture', version: 'abc')
  end

  it 'fails closed after revocation, mode change or contact change' do
    JrcNico::ErpSetting.create!(account: account, mode: 'fixture')
    with_modified_env ERP_ALLOWED_ACCOUNTS: account.id.to_s do
      expect(described_class.allowed?(account: account, user: admin, conversation: conversation, binding: binding)).to be true
      binding.update!(enabled: false)
      expect(described_class.allowed?(account: account, user: admin, conversation: conversation, binding: binding)).to be false
      binding.update!(enabled: true)
      JrcNico::ErpSetting.find_by!(account: account).update!(mode: 'off')
      expect(described_class.allowed?(account: account, user: admin, conversation: conversation, binding: binding)).to be false
    end
  end
end
