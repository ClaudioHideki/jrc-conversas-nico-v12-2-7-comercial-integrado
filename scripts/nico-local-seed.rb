abort 'Dedicated local development database required' unless Rails.env.development? && ENV['JRC_NICO_LOCAL_SEED'] == 'true' && ActiveRecord::Base.connection_db_config.database == 'jrc_nico_homologacao'
password = ENV.fetch('NICO_LOCAL_PASSWORD')
abort 'Strong local password required' if password.length < 20
GlobalConfig.clear_cache
ConfigLoader.new.process

ActiveRecord::Base.transaction do
  [['GoPure Homologação', 'admin@gopure.test'], ['Conta Isolada Homologação', 'admin@isolada.test']].each_with_index do |(name, email), index|
    account = Account.find_by(name: name) || Account.create!(name: name, locale: 'pt_BR')
    abort 'Unexpected account IDs: use a fresh dedicated local database' unless account.id == index + 1
    account.update!(custom_attributes: account.custom_attributes.merge('nico_enabled' => true, 'nico_monthly_run_limit' => 1000, 'nico_monthly_token_limit' => 1_000_000))
    account.enable_features!('jrc_crm', 'jrc_campaigns', 'automations')
    user = User.find_by(email: email)
    unless user
      user = User.new(name: "Administrador #{name}", email: email, password: password, password_confirmation: password)
      user.skip_confirmation!
      user.save!
    end
    AccountUser.find_or_create_by!(account: account, user: user) { |membership| membership.role = :administrator }
    inbox = account.inboxes.find_by(name: 'Canal sintético local')
    unless inbox
      channel = Channel::Api.create!(account: account)
      inbox = Inbox.create!(account: account, channel: channel, name: 'Canal sintético local')
    end
    InboxMember.find_or_create_by!(inbox: inbox, user: user)
    contact_inbox = ContactInboxWithContactBuilder.new(source_id: "nico-local-#{index}", inbox: inbox, hmac_verified: true,
                                                       contact_attributes: { name: "Cliente Sintético #{index + 1}", email: "cliente#{index + 1}@example.test" }).perform
    conversation = account.conversations.find_by(contact_inbox: contact_inbox) || Conversation.create!(account: account, inbox: inbox,
                     contact: contact_inbox.contact, contact_inbox: contact_inbox, assignee: user, status: :open)
    unless conversation.messages.exists?
      Message.create!(account: account, inbox: inbox, conversation: conversation, sender: contact_inbox.contact, message_type: :incoming,
                      content: "Demonstração da conta #{index + 1}: preciso de informações sobre implantação e suporte.")
    end
    JrcCrm::DefaultPipelineService.new(account).perform
    JrcCrm::Lead.find_or_create_by!(account: account, contact: contact_inbox.contact) do |lead|
      lead.owner = user
      lead.name = "Oportunidade sintética #{index + 1}"
      lead.company_name = name
      lead.email = contact_inbox.contact.email
      lead.source = 'manual'
      lead.status = 'new'
      lead.notes = 'Dados fictícios para validar isolamento e atividade aprovada. Sem envio externo.'
    end
    JrcNico::KnowledgeDocument.find_or_create_by!(account: account, title: 'Procedimento de demonstração — implantação e suporte') do |doc|
      doc.author = user
      doc.approved_by = user
      doc.approved_at = Time.current
      doc.body = 'Conteúdo fictício aprovado apenas para homologação. Implantação e suporte: registrar a necessidade, conferir o contexto e encaminhar ao responsável humano. Não representa uma política comercial GoPure.'
    end
    if index.zero?
      operator = User.find_by(email: 'operator@gopure.test')
      unless operator
        operator = User.new(name: 'Atendente local', email: 'operator@gopure.test', password: password, password_confirmation: password)
        operator.skip_confirmation!
        operator.save!
      end
      AccountUser.find_or_create_by!(account: account, user: operator) { |membership| membership.role = :agent }
      InboxMember.find_or_create_by!(inbox: inbox, user: operator)
    end
    puts "Account #{account.id}: #{email}; conversation #{conversation.reload.display_id}; synthetic only"
  end
end
puts 'Local seed ready. Password remains in local/nico.env.'
