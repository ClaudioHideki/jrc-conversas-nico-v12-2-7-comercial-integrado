abort 'Dedicated local development database required' unless Rails.env.development? && ENV['JRC_NICO_LOCAL_SEED'] == 'true' &&
                                                            ActiveRecord::Base.connection_db_config.database == 'jrc_nico_homologacao'

account = Account.find_by!(name: 'GoPure Homologação')
admin = User.find_by!(email: 'admin@gopure.test')
inbox = account.inboxes.find_by!(name: 'Canal sintético local')
cnpj = '28240080000171'
scenarios = [
  {
    number: 1, agent: 'comercial', title: 'Novo lead comercial',
    message: 'Olá, quero contratar os serviços da JRC. Preciso de uma proposta para telefonia e ainda não sou cliente. Quem pode me ajudar?'
  },
  {
    number: 2, agent: 'suporte_n1', title: 'Suporte e chamado',
    message: "Somos da empresa CAVALARI, CNPJ #{cnpj}. Um ramal está sem áudio. Existem chamados abertos e vocês podem preparar um novo chamado?"
  },
  {
    number: 3, agent: 'financeiro', title: 'Financeiro e cobranças',
    message: "Empresa CAVALARI, CNPJ #{cnpj}. Gostaria de confirmar nossa situação cadastral e se existem faturas ou cobranças em aberto."
  },
  {
    number: 4, agent: 'implantacao', title: 'Implantação',
    message: "Empresa CAVALARI, CNPJ #{cnpj}. Precisamos implantar novos ramais, organizar treinamento e entender as pendências antes da ativação."
  },
  {
    number: 5, agent: 'cx', title: 'CX e risco de cancelamento',
    message: "Empresa CAVALARI, CNPJ #{cnpj}. Estamos insatisfeitos com a demora e pensando em cancelar. Existem chamados pendentes sem retorno?"
  }
]

setting = JrcNico::ErpSetting.find_or_initialize_by(account: account)
setting.update!(mode: 'live', operator_company_id: '3', requester_user_id: '4912')

ActiveRecord::Base.transaction do
  scenarios.each do |scenario|
    source_id = "nico-scenario-#{scenario[:number]}"
    contact_inbox = ContactInbox.find_by(source_id: source_id, inbox: inbox)
    contact_inbox ||= ContactInboxWithContactBuilder.new(
      source_id: source_id,
      inbox: inbox,
      hmac_verified: true,
      contact_attributes: {
        name: "Cliente IA #{scenario[:number]} — #{scenario[:title]}",
        email: "cliente.ia#{scenario[:number]}@example.test"
      }
    ).perform
    conversation = account.conversations.find_or_create_by!(contact_inbox: contact_inbox) do |record|
      record.inbox = inbox
      record.contact = contact_inbox.contact
      record.assignee = admin
      record.status = :open
    end
    message = conversation.messages.find_or_create_by!(source_id: "scenario-message-#{scenario[:number]}") do |record|
      record.account = account
      record.inbox = inbox
      record.sender = contact_inbox.contact
      record.message_type = :incoming
      record.content = scenario[:message]
    end
    recommendation = JrcNico::IntentClassifier.call(message)
    conversation.update!(custom_attributes: conversation.custom_attributes.to_h.merge('nico_assistance' => recommendation))

    if scenario[:number] > 1
      binding = JrcNico::ErpBinding.find_or_initialize_by(account: account, contact: contact_inbox.contact)
      binding.update!(cnpj: cnpj, customer_name: 'CAVALARI PARTICIPAÇÕES EIRELI', bemtevi_customer_id: '152',
                      helpdesk_company_id: '536', mode: 'live', enabled: true, verified_by: admin, version: SecureRandom.hex(12))
    end
    puts "Cliente IA #{scenario[:number]}: conversa #{conversation.reload.display_id}; esperado #{scenario[:agent]}; detectado #{recommendation['agent_key']}"
  end
end

puts 'Cinco cenários criados. ERP permanece somente leitura; nenhum chamado, cobrança ou mensagem externa foi gerado.'
