abort 'Dedicated local development database required' unless Rails.env.development? && ENV['JRC_NICO_LOCAL_SEED'] == 'true' &&
                                                            ActiveRecord::Base.connection_db_config.database == 'jrc_nico_homologacao'

account = Account.find_by!(name: 'GoPure Homologação')
admin = User.find_by!(email: 'admin@gopure.test')
inbox = account.inboxes.find_by!(name: 'Canal sintético local')
cnpj = '28240080000171'
scenarios = [
  ['finance-value', 'Financeiro - valor e vencimento', "Empresa CAVALARI, CNPJ #{cnpj}. Qual é o valor exato e o vencimento da fatura que está em aberto?"],
  ['finance-copy', 'Financeiro - segunda via', "Empresa CAVALARI, CNPJ #{cnpj}. Preciso gerar a segunda via do boleto em aberto e receber o link ou PDF para pagamento."],
  ['support-list', 'Suporte - consultar chamados', "Empresa CAVALARI, CNPJ #{cnpj}. Consulte os chamados abertos e informe os protocolos e status atuais."],
  ['support-create', 'Suporte - preparar novo chamado', "Empresa CAVALARI, CNPJ #{cnpj}. O ramal 204 está sem áudio. Verifique os chamados existentes e prepare a abertura de um novo chamado." ]
]

scenarios.each_with_index do |(key, title, content), index|
  source_id = "nico-diagnostic-#{key}"
  contact_inbox = ContactInbox.find_by(source_id: source_id, inbox: inbox) || ContactInboxWithContactBuilder.new(
    source_id: source_id, inbox: inbox, hmac_verified: true,
    contact_attributes: { name: "Cliente Diagnóstico #{index + 1} - #{title}", email: "diagnostico.#{key}@example.test" }
  ).perform
  conversation = account.conversations.find_or_create_by!(contact_inbox: contact_inbox) do |record|
    record.inbox = inbox
    record.contact = contact_inbox.contact
    record.assignee = admin
    record.status = :open
  end
  message = conversation.messages.find_or_create_by!(source_id: "#{source_id}-message") do |record|
    record.account = account
    record.inbox = inbox
    record.sender = contact_inbox.contact
    record.message_type = :incoming
    record.content = content
  end
  recommendation = JrcNico::IntentClassifier.call(message)
  conversation.update!(custom_attributes: conversation.custom_attributes.to_h.merge('nico_assistance' => recommendation))
  binding = JrcNico::ErpBinding.find_or_initialize_by(account: account, contact: contact_inbox.contact)
  binding.update!(cnpj: cnpj, customer_name: 'CAVALARI PARTICIPAÇÕES EIRELI', bemtevi_customer_id: '152',
                  helpdesk_company_id: '536', mode: 'live', enabled: true, verified_by: admin, version: SecureRandom.hex(12))
  puts({ key: key, conversation: conversation.reload.display_id, detected: recommendation['agent_key'], status: recommendation['status'] }.to_json)
end

puts 'Cenários diagnósticos criados; nenhuma mensagem externa, cobrança, boleto ou chamado foi gerado.'
