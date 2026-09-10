# Local-only fixture: one API-channel customer, without external delivery.
raise 'Execute apenas no ambiente local de desenvolvimento' unless Rails.env.development? && ENV['JRC_NICO_LOCAL_STATIC'] == 'true'
account = Account.find(1)
raise 'A conta de teste possui webhooks ou automações' if account.webhooks.exists? || account.automation_rules.exists?
user = account.users.find_by!(email: 'admin@gopure.test')
inbox = account.inboxes.find_or_initialize_by(name: 'NICO — Simulador de cliente')
if inbox.new_record?
  inbox.channel = Channel::Api.create!(account: account, webhook_url: nil)
  inbox.enable_auto_assignment = false
  inbox.save!
end
raise 'O simulador exige um canal API sem webhook' unless inbox.channel_type == 'Channel::Api' && inbox.channel.webhook_url.blank?
inbox.inbox_members.find_or_create_by!(user: user)
contact = account.contacts.find_or_create_by!(identifier: 'nico-local-customer-simulator') do |record|
  record.name = 'Marina — Cliente Simulado NICO'
end
raise 'Contato de teste não pode ter endereço externo' if contact.email.present? || contact.phone_number.present?
link = ContactInbox.find_or_create_by!(inbox: inbox, contact: contact) { |record| record.source_id = SecureRandom.uuid }
conversation = account.conversations.find_by(inbox: inbox, contact: contact) ||
               account.conversations.create!(inbox: inbox, contact: contact, contact_inbox: link, status: 'open')
config = {
  name: contact.name, contact_id: contact.id, conversation_id: conversation.display_id, inbox_name: inbox.name,
  customer_path: "/public/api/v1/inboxes/#{inbox.channel.identifier}/contacts/#{link.source_id}/conversations/#{conversation.display_id}",
  operator_path: "/app/accounts/#{account.id}/conversations/#{conversation.display_id}"
}
destination = Rails.root.join('public/nico-cliente-teste')
FileUtils.mkdir_p(destination)
%w[index.html client.js styles.css].each do |name|
  FileUtils.cp(Rails.root.join('scripts/nico-customer-simulator', name), destination.join(name))
end
# Only this fictitious customer's public-channel identifiers. No operator token or provider key.
File.write(destination.join('config.json'), JSON.pretty_generate(config))
File.write(Rails.root.join('local/nico-customer-simulator.json'), JSON.pretty_generate(config))
puts({ contact_id: contact.id, conversation_id: conversation.display_id, inbox_id: inbox.id,
       customer_url: 'http://localhost:3107/nico-cliente-teste/', operator_path: config[:operator_path] }.to_json)

