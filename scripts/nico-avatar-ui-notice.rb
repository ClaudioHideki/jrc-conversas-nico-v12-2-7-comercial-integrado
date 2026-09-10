abort 'Somente homologação local' unless Rails.env.development? && ENV['JRC_NICO_LOCAL_STATIC'] == 'true'

config = JSON.parse(Rails.root.join('local/nico-customer-simulator.json').read)
contact = Contact.find(config.fetch('contact_id'))
abort 'Contato fora do simulador' unless contact.identifier == 'nico-local-customer-simulator'
conversation = contact.conversations.find_by!(display_id: config.fetch('conversation_id'))
delegation = JrcNico::Delegation.find_by!(conversation: conversation)
notice = JrcNico::Notice.publish!(
  account: contact.account, user: delegation.user, conversation: conversation,
  event_key: 'avatar-ui-validation-20260910', kind: 'attention',
  body: 'Validação local: Marina tem uma demonstração registrada no CRM. Quer conferir o próximo passo?',
  metadata: { route_name: 'crm_activities' }
)
puts({ notice_id: notice.id, conversation_id: conversation.display_id, unread: notice.read_at.nil? }.to_json)
