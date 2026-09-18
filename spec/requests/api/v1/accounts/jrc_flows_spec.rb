require 'rails_helper'

RSpec.describe 'JRC Flows access and execution', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:channel_api, account: account).inbox }
  let(:other_inbox) { create(:channel_api, account: account).inbox }
  let(:prefix) { "/api/v1/accounts/#{account.id}/jrc_flows" }
  let(:graph) do
    {
      'nodes' => [
        { 'id' => 'start', 'type' => 'start', 'label' => 'Início', 'position' => { 'x' => 0, 'y' => 0 }, 'data' => {} },
        { 'id' => 'ask', 'type' => 'message', 'label' => 'Pergunta', 'position' => { 'x' => 250, 'y' => 0 }, 'data' => { 'text' => 'Qual é seu nome?' } },
        { 'id' => 'input', 'type' => 'input', 'label' => 'Captura', 'position' => { 'x' => 500, 'y' => 0 },
          'data' => { 'variable' => 'nome', 'timeout' => 60 } },
        { 'id' => 'reply', 'type' => 'message', 'label' => 'Resposta', 'position' => { 'x' => 750, 'y' => 0 },
          'data' => { 'text' => 'Olá, {{nome}}!' } },
        { 'id' => 'end', 'type' => 'end', 'label' => 'Fim', 'position' => { 'x' => 1000, 'y' => 0 }, 'data' => {} }
      ],
      'edges' => [
        { 'id' => 'a', 'source' => 'start', 'target' => 'ask', 'port' => 'next' },
        { 'id' => 'b', 'source' => 'ask', 'target' => 'input', 'port' => 'next' },
        { 'id' => 'c', 'source' => 'input', 'target' => 'reply', 'port' => 'next' },
        { 'id' => 'd', 'source' => 'input', 'target' => 'end', 'port' => 'timeout' },
        { 'id' => 'e', 'source' => 'reply', 'target' => 'end', 'port' => 'next' }
      ]
    }
  end
  let(:flow) do
    JrcFlow.create!(account: account, created_by: admin, name: 'Triagem JRC', graph: graph,
                    settings: { 'inbox_ids' => [inbox.id], 'days' => [1, 2, 3, 4, 5], 'trigger' => 'message_created' })
  end

  around do |example|
    with_modified_env(JRC_FLOWS_ENABLED: 'true', JRC_FLOWS_EXTERNAL_BETA: 'false') { example.run }
  end

  before do
    account.enable_features!('jrc_flows')
  end

  it 'blocks the module when the account or installation disables it' do
    headers = admin.create_new_auth_token
    with_modified_env(JRC_FLOWS_ENABLED: 'false') do
      get prefix, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
    account.disable_features!('jrc_flows')
    get prefix, headers: headers
    expect(response).to have_http_status(:unauthorized)
  end

  it 'shows the agent only assigned inbox flows and never exposes definitions or credentials' do
    create(:inbox_member, inbox: inbox, user: agent)
    flow.connection_secrets = { 'http_api_key' => 'synthetic-flow-secret' }
    flow.save!
    hidden = flow.dup
    hidden.update!(name: 'Outra caixa', settings: flow.settings.merge('inbox_ids' => [other_inbox.id]))
    headers = agent.create_new_auth_token
    get prefix, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.pluck('id')).to eq([flow.id])
    expect(response.body).not_to include('graph', 'settings', 'synthetic-flow-secret', 'credential')
    get "#{prefix}/metadata", headers: headers
    expect(response.parsed_body['inboxes'].pluck('id')).to eq([inbox.id])
    get "#{prefix}/#{hidden.id}/runs", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'denies definition access and mutations to agents and all access to another account' do
    create(:inbox_member, inbox: inbox, user: agent)
    get "#{prefix}/#{flow.id}", headers: agent.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
    post "#{prefix}/#{flow.id}/activate", headers: agent.create_new_auth_token, params: {}, as: :json
    expect(response).to have_http_status(:unauthorized)
    stranger = create(:user, account: create(:account), role: :administrator)
    get prefix, headers: stranger.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end

  it 'keeps the external portal, connection API and webhook disabled by default' do
    get '/flows/portal'
    expect(response).to have_http_status(:not_found)
    post '/jrc_flows/events/unknown', params: {}, as: :json
    expect(response).to have_http_status(:not_found)
    get "/api/v1/accounts/#{account.id}/jrc_flow_connections", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:not_found)
  end

  it 'round trips native JSON without exporting protected credentials' do
    flow.connection_secrets = { 'openai_api_key' => 'synthetic-protected-key' }
    flow.save!
    exported = flow.export_definition.to_json
    expect(exported).not_to include('synthetic-protected-key', 'credential_ciphertext')
    restored = JrcFlows::Importer.new("\uFEFF#{exported}").attributes
    expect(restored['graph']).to eq(flow.graph)
    expect(restored['engine']).to eq('native')
    expect(restored['settings']['inbox_ids']).to eq([inbox.id])
  end

  it 'preserves imported workflow nodes but refuses activation with a missing subworkflow' do
    document = {
      'name' => 'Subworkflow pendente',
      'nodes' => [
        { 'id' => 'entry', 'name' => 'Entrada', 'type' => 'n8n-nodes-base.webhook', 'parameters' => {} },
        { 'id' => 'child', 'name' => 'Subflow', 'type' => 'n8n-nodes-base.executeWorkflow', 'parameters' => { 'workflowId' => 'n8n-original-id' } }
      ],
      'connections' => { 'Entrada' => { 'main' => [[{ 'node' => 'Subflow', 'type' => 'main', 'index' => 0 }]] } }
    }
    attributes = JrcFlows::Importer.new(document.to_json).attributes
    imported = JrcFlow.create!(attributes.merge('account' => account, 'created_by' => admin))
    expect(imported.reload.source_definition).to eq(document)
    expect(imported.export_definition[:workflow]).to eq(document)
    expect(imported.update(status: 'active')).to be(false)
    expect(imported.errors.full_messages.join(' ')).to include('importe e selecione o subworkflow')
  end

  it 'runs the native chatbot through a persisted reply and blocks delivery after feature revocation' do
    flow.update!(status: 'active')
    conversation = create(:conversation, account: account, inbox: inbox, assignee: nil, status: :pending)
    incoming = create(:message, conversation: conversation, account: account, message_type: :incoming, content: 'Olá')
    JrcFlows::DispatchJob.perform_now(account.id, conversation.id, 'message_created', "message:#{incoming.id}", incoming.id)
    run = flow.runs.last
    expect(run.status).to eq('waiting')
    expect(conversation.messages.outgoing.last.content).to eq('Qual é seu nome?')
    answer = create(:message, conversation: conversation, account: account, message_type: :incoming, content: 'Cliente de teste')
    JrcFlows::Runner.new(run.reload).perform(message: answer)
    expect(run.reload.status).to eq('completed')
    reply = conversation.messages.outgoing.order(:id).last
    expect(reply.content).to eq('Olá, Cliente de teste!')
    account.disable_features!('jrc_flows')
    delivered = false
    JrcFlows::Delivery.new(reply).perform { delivered = true }
    expect(delivered).to be(false)
    expect(reply.reload.content_attributes['jrc_flow_delivery']).to eq('cancelled')
  end

  it 'does not start a native flow when an inbox Agent Bot owns the channel' do
    flow.update!(status: 'active')
    conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)
    create(:agent_bot_inbox, inbox: inbox, agent_bot: create(:agent_bot, account: account))
    incoming = create(:message, conversation: conversation, account: account, message_type: :incoming, content: 'Teste sintético')
    expect(conversation.reload.assignee_agent_bot_id).to be_nil
    JrcFlows::DispatchJob.perform_now(account.id, conversation.id, 'message_created', "message:#{incoming.id}", incoming.id)
    expect(flow.runs.count).to eq(0)
  end

  it 'pauses an existing native run and cancels its queued reply after a bot is attached to the inbox' do
    flow.update!(status: 'active')
    conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)
    incoming = create(:message, conversation: conversation, account: account, message_type: :incoming, content: 'Teste sintético')
    JrcFlows::DispatchJob.perform_now(account.id, conversation.id, 'message_created', "message:#{incoming.id}", incoming.id)
    run = flow.runs.last
    reply = conversation.messages.outgoing.last
    create(:agent_bot_inbox, inbox: inbox, agent_bot: create(:agent_bot, account: account))
    answer = create(:message, conversation: conversation, account: account, message_type: :incoming, content: 'Ana')
    JrcFlows::Runner.new(run.reload).perform(message: answer)
    expect(run.reload.status).to eq('paused')
    delivered = false
    JrcFlows::Delivery.new(reply).perform { delivered = true }
    expect(delivered).to be(false)
    expect(reply.reload.content_attributes['jrc_flow_delivery']).to eq('cancelled')
  end
end
