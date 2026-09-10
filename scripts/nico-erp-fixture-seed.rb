abort 'Dedicated local database required' unless Rails.env.development? && ENV['JRC_NICO_LOCAL_SEED'] == 'true' && ActiveRecord::Base.connection_db_config.database == 'jrc_nico_homologacao'
account = Account.find(1)
abort 'GoPure homologation account required' unless account.name == 'GoPure Homologação'
admin = User.find_by!(email: 'admin@gopure.test')
conversation = account.conversations.joins(:inbox).find_by!(inboxes: { name: 'Canal sintético local' })
if JrcNico::ErpSetting.exists?(account: account) || JrcNico::ErpBinding.exists?(account: account, contact: conversation.contact)
  puts 'Configuração ERP existente preservada; fixture não foi aplicada.'
  exit 0
end
setting = JrcNico::ErpSetting.new(account: account)
setting.update!(mode: 'fixture', operator_company_id: '3', requester_user_id: '4912')
binding = JrcNico::ErpBinding.find_or_initialize_by(account: account, contact: conversation.contact)
binding.update!(cnpj: '11222333000181', customer_name: 'Cliente fictício GoPure', bemtevi_customer_id: '900001', helpdesk_company_id: '900002',
                mode: 'fixture', enabled: true, verified_by: admin, version: SecureRandom.hex(12))
puts 'GoPure: vínculo fictício preparado; nenhum ERP real foi vinculado ao contato sintético.'

