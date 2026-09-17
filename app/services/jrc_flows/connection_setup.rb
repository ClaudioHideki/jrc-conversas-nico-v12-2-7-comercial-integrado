class JrcFlows::ConnectionSetup
  def initialize(connection)
    @connection = connection
    @client = JrcFlows::ChatwootClient.new(connection, provisioning: true)
  end

  def verify
    inboxes = JrcFlows::ChatwootClient.list(@client.call(:get, 'inboxes'))
    teams = JrcFlows::ChatwootClient.list(@client.call(:get, 'teams'))
    agents = JrcFlows::ChatwootClient.list(@client.call(:get, 'agents'))
    labels = JrcFlows::ChatwootClient.list(@client.call(:get, 'labels'))
    catalog = { 'inboxes' => inboxes.map { |i| i.slice('id', 'name', 'channel_type') }, 'teams' => teams.map { |i| i.slice('id', 'name') },
      'agents' => agents.map { |i| i.slice('id', 'name') }, 'labels' => labels.map { |i| i['title'] } }
    @connection.update!(catalog: catalog, verified_at: Time.current)
  end

  def install
    verify
    allowed = @connection.catalog.fetch('inboxes').pluck('id')
    raise JrcFlows::ChatwootClient::Error, 'Selecione caixas existentes no Chatwoot de destino.' if @connection.inbox_ids.empty? || (@connection.inbox_ids - allowed).any?
    # Existing inbox bots must never be silently replaced.
    @connection.inbox_ids.each do |id|
      attached = @client.call(:get, "inboxes/#{id}/agent_bot") || {}
      attached = attached['agent_bot'] || attached
      if attached['id'].present? && attached['id'] != @connection.bot_id
        raise JrcFlows::ChatwootClient::Error, "A caixa #{id} já possui outro bot. Desvincule-o no Chatwoot antes de instalar."
      end
    end
    bot = if @connection.bot_id
            @client.call(:get, "agent_bots/#{@connection.bot_id}")
          else
            @client.call(:post, 'agent_bots', { name: 'JRC Flows', description: 'Workflows e atendimento automatizado', outgoing_url: @connection.webhook_url })
          end
    token = bot['access_token'].is_a?(Hash) ? bot.dig('access_token', 'token') : bot['access_token']
    # Keep the bot ID even if this version cannot sign events, so a retry cannot create duplicates.
    @connection.update!(bot_id: bot.fetch('id'))
    if token.blank? || bot['secret'].blank?
      raise JrcFlows::ChatwootClient::Error, 'Esta instalação não forneceu token e segredo de assinatura do bot. Atualize o Chatwoot ou configure um conector autenticado compatível.'
    end
    @connection.update!(secrets: { 'bot_token' => token, 'webhook_secret' => bot['secret'] })
    @connection.inbox_ids.each { |id| @client.call(:post, "inboxes/#{id}/set_agent_bot", { agent_bot: @connection.bot_id }) }
    unless @connection.dashboard_app_id
      app = @client.call(:post, 'dashboard_apps', { dashboard_app: { title: 'Flows', content: [{ type: 'frame', url: @connection.portal_url }] } })
      @connection.update!(dashboard_app_id: app.fetch('id'))
    end
    @connection.update!(enabled: true)
  end

  def disconnect
    @connection.update!(enabled: false)
    @connection.remote_sessions.where(status: %w[ready running waiting delayed]).update_all(status: 'paused', error: 'Conexão desativada.', wake_at: nil)
    @connection.inbox_ids.each do |id|
      bot = @client.call(:get, "inboxes/#{id}/agent_bot") || {}
      bot = bot['agent_bot'] || bot
      @client.call(:post, "inboxes/#{id}/set_agent_bot", { agent_bot: nil }) if bot['id'] == @connection.bot_id
    end
  end
end
