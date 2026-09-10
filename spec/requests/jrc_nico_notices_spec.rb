require 'rails_helper'

RSpec.describe 'NICO customer actions and notices', type: :request do
  let(:account) { create(:account, custom_attributes: { 'nico_enabled' => true }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:base) { "/api/v1/accounts/#{account.id}/jrc_nico/operations" }
  let(:conversation) { create(:conversation, account: account) }
  let(:notice) do
    JrcNico::Notice.publish!(account: account, user: admin, conversation: conversation,
      event_key: 'test-action', kind: 'action', request: 'Atualize meu email para marina@example.test', body: 'Cliente pediu atualização de cadastro')
  end

  it 'prepares a customer action without cancelling the operator task, then notifies its real result' do
    post "#{base}/prepare", params: { request_id: SecureRandom.uuid, message: 'Outro trabalho', tool: 'create_contact',
      arguments: { name: 'Outro cliente', email: 'outro@example.test' } }, headers: headers, as: :json
    other_id = response.parsed_body['commands'].first['id']
    allow(JrcNico::OperationalInference).to receive(:call) do |**args|
      expect(args[:history]).to be_empty
      expect(args[:context][:selected_conversation][:contact_id]).to eq(conversation.contact_id)
      { 'reply' => 'Atualizar o email deste cliente', 'tool' => 'update_contact',
        'arguments' => { 'contact_id' => conversation.contact_id, 'email' => 'marina@example.test' } }
    end
    expect { JrcNico::NoticePlanJob.perform_now(notice.id) }.not_to change { conversation.contact.reload.email }
    command = notice.commands.last
    expect(command.status).to eq('awaiting_confirmation')
    expect(JrcNico::Command.find(other_id).status).to eq('awaiting_confirmation')
    post "#{base}/commands/#{command.id}/confirm", headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(conversation.contact.reload.email).to eq('marina@example.test')
    expect(notice.reload.status).to eq('succeeded')
    expect(notice.read_at).to be_nil
    expect { post "#{base}/commands/#{command.id}/confirm", headers: headers, as: :json }.not_to change { conversation.contact.reload.updated_at }
  end

  it 'does not prepare an action on another customer, even in the same account' do
    other = create(:contact, account: account, name: 'Outro cliente')
    allow(JrcNico::OperationalInference).to receive(:call).and_return(
      'reply' => 'Trocar dados', 'tool' => 'update_contact', 'arguments' => { 'contact_id' => other.id, 'name' => 'Não alterar' })
    JrcNico::NoticePlanJob.perform_now(notice.id)
    expect(notice.commands.last.status).to eq('failed')
    expect(other.reload.name).to eq('Outro cliente')
  end

  it 'retains customer previews when the operator sends another unrelated request' do
    command = JrcNico::OperatorSession.new(account: account, user: admin).session.commands.create!(
      source_notice: notice, request_id: SecureRandom.uuid, message: notice.request, status: 'awaiting_confirmation',
      tool: 'update_contact', arguments: { contact_id: conversation.contact_id, email: 'new@example.test' })
    post "#{base}/prepare", params: { request_id: SecureRandom.uuid, message: 'Outra tarefa', tool: 'create_contact',
      arguments: { name: 'Outro', email: 'outro@example.test' } }, headers: headers, as: :json
    expect(command.reload.status).to eq('awaiting_confirmation')
  end

  it 'shows persistent notifications only to their owner and supports marking them read' do
    notice
    get "#{base}/notices", headers: headers
    expect(response.parsed_body['unread_count']).to eq(1)
    expect(response.parsed_body['notices'].first['conversation_id']).to eq(conversation.display_id)
    other = create(:user, account: account, role: :administrator)
    get "#{base}/notices", headers: other.create_new_auth_token
    expect(response.parsed_body['notices']).to be_empty
    post "#{base}/notices/#{notice.id}/read", headers: other.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    post "#{base}/notices/#{notice.id}/read", headers: headers, as: :json
    expect(response.parsed_body['unread_count']).to eq(0)
  end

  it 'revalidates conversation access before approving a queued customer action' do
    command = JrcNico::OperatorSession.new(account: account, user: admin).session.commands.create!(
      source_notice: notice, request_id: SecureRandom.uuid, message: notice.request, status: 'awaiting_confirmation',
      tool: 'update_contact', arguments: { contact_id: conversation.contact_id, email: 'new@example.test' })
    account.update!(custom_attributes: { 'nico_enabled' => false })
    post "#{base}/commands/#{command.id}/confirm", headers: headers, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(conversation.contact.reload.email).not_to eq('new@example.test')
  end

  it 'does not repeat a completed action while planning the next step' do
    operator = JrcNico::OperatorSession.new(account: account, user: admin)
    args = { 'contact_id' => conversation.contact_id, 'email' => 'new@example.test' }
    operator.session.commands.create!(source_notice: notice, request_id: SecureRandom.uuid, message: notice.request,
      status: 'succeeded', tool: 'update_contact', arguments: args, reply: 'Concluído')
    allow(JrcNico::OperationalInference).to receive(:call).and_return('tool' => 'update_contact', 'arguments' => args, 'reply' => 'Repetir')
    JrcNico::NoticePlanJob.perform_now(notice.id)
    expect(notice.commands.last.tool).to be_nil
    expect(notice.reload.status).to eq('review')
  end

  it 'removes greetings only on continuation replies and preserves the customer name and content' do
    expect(JrcNico::CustomerReply.normalize('Olá, Marina! Vamos continuar.', continuation: true)).to eq('Marina! Vamos continuar.')
    expect(JrcNico::CustomerReply.normalize('Bom dia! O agendamento precisa de um horário.', continuation: true)).to eq('O agendamento precisa de um horário.')
    expect(JrcNico::CustomerReply.normalize('Olá, sou o NICO.', continuation: false)).to eq('Olá, sou o NICO.')
    expect(JrcNico::CustomerReply.normalize('O produto se chama Olá.', continuation: true)).to eq('O produto se chama Olá.')
  end

  it 'omits optional nulls from model arguments without accepting unknown or required null fields' do
    account.enable_features!('jrc_crm')
    access = JrcNico::OperationalAccess.new(account: account, user: admin).authorize!
    catalog = JrcNico::ToolCatalog.new(access)
    args = { 'title' => 'Reunião', 'activity_type' => 'meeting', 'due_at' => '2026-09-11T15:00:00-03:00', 'lead_id' => nil, 'deal_id' => 1 }
    normalized = catalog.normalize_arguments('create_activity', args)
    expect(normalized).not_to have_key('lead_id')
    expect { catalog.validate!('create_activity', normalized) }.not_to raise_error
    expect { catalog.validate!('create_activity', catalog.normalize_arguments('create_activity', args.merge('title' => nil))) }.to raise_error(ArgumentError)
    expect { catalog.validate!('create_activity', catalog.normalize_arguments('create_activity', args.merge('unknown' => nil))) }.to raise_error(ArgumentError)
  end

  it 'lets the planner correct incomplete activity arguments using actual records before review' do
    account.enable_features!('jrc_crm')
    lead = account.jrc_crm_leads.create!(name: 'Cliente teste', contact: conversation.contact, owner: admin)
    args = { 'title' => 'Reunião', 'activity_type' => 'meeting', 'due_at' => 2.days.from_now.iso8601, 'lead_id' => nil }
    allow(JrcNico::OperationalInference).to receive(:call).and_return(
      { 'tool' => 'create_activity', 'arguments' => args, 'reply' => 'Agendar' },
      { 'tool' => 'list_leads', 'arguments' => { 'contact_id' => conversation.contact_id }, 'reply' => 'Localizar lead' },
      { 'tool' => 'create_activity', 'arguments' => args.merge('lead_id' => lead.id), 'reply' => 'Agendar no lead encontrado' })
    expect { JrcNico::NoticePlanJob.perform_now(notice.id) }.not_to change { account.jrc_crm_activities.count }
    command = notice.commands.last
    expect(command.status).to eq('awaiting_confirmation')
    expect(command.arguments['lead_id']).to eq(lead.id)
    post "#{base}/commands/#{command.id}/confirm", headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(account.jrc_crm_activities.last.lead).to eq(lead)
  end

  it 'preserves the actionable error and allows only the owner to retry failed planning' do
    allow(JrcNico::OperationalInference).to receive(:call).and_raise(ArgumentError, 'Informe o horário da reunião.')
    JrcNico::NoticePlanJob.perform_now(notice.id)
    expect(notice.reload.status).to eq('failed')
    expect(notice.body).to eq('Informe o horário da reunião.')
    other = create(:user, account: account, role: :administrator)
    post "#{base}/notices/#{notice.id}/retry", headers: other.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect { post "#{base}/notices/#{notice.id}/retry", headers: headers, as: :json }.to have_enqueued_job(JrcNico::NoticePlanJob).with(notice.id)
    expect(response).to have_http_status(:ok)
    expect(notice.reload.status).to eq('planning')
    expect { post "#{base}/notices/#{notice.id}/retry", headers: headers, as: :json }.not_to have_enqueued_job(JrcNico::NoticePlanJob)
  end
end
