class JrcFlows::Importer
  class Invalid < StandardError; end
  MAX_BYTES = 2.megabytes

  def initialize(content)
    raise Invalid, 'Selecione um JSON de até 2 MB.' unless content.is_a?(String) && content.bytesize <= MAX_BYTES

    @document = JSON.parse(content.delete_prefix("\uFEFF"))
    raise Invalid, 'O JSON deve conter um objeto de workflow.' unless @document.is_a?(Hash)
  rescue JSON::ParserError
    raise Invalid, 'JSON inválido. Exporte o arquivo completo do JRC ou do n8n.'
  end

  def attributes
    if %w[jrc-flows/1 jrc-flows/2].include?(@document['format'])
      data = @document['flow']
      raise Invalid, 'O arquivo JRC não contém um fluxo válido.' unless data.is_a?(Hash)

      result = data.slice('name', 'description', 'kind', 'graph', 'settings', 'engine')
      result['engine'] ||= 'native'
      result['source_definition'] = validate_n8n(@document['workflow']) if result['engine'] == 'workflow'
      result
    elsif @document['nodes'].is_a?(Array) && @document['connections'].is_a?(Hash)
      workflow = validate_n8n(@document)
      {
        'name' => workflow['name'].to_s.first(120).presence || 'Workflow', 'kind' => 'chatbot', 'engine' => 'workflow',
        'source_definition' => workflow,
        'graph' => { 'nodes' => [
          { id: 'start', type: 'start', label: 'Mensagem recebida', position: { x: 60, y: 80 }, data: {} },
          { id: 'end', type: 'end', label: 'Execução no JRC', position: { x: 360, y: 80 }, data: {} }
        ], 'edges' => [{ id: 'start-end', source: 'start', target: 'end', port: 'next' }] },
        'settings' => { 'inbox_ids' => [], 'days' => [1, 2, 3, 4, 5], 'trigger' => 'message_created',
                        'pause_on_agent' => true, 'pause_on_team' => false, 'restart_on_resolve' => true,
                        'response_contract' => 'ligo', 'environment' => 'HML' }
      }
    else
      raise Invalid, 'Formato não reconhecido. Aceitamos JRC Flows e workflows n8n. JSONs do Typebot exigem seu próprio adaptador.'
    end
  end

  def preview
    data = attributes
    data.except('source_definition').merge('external' => data['engine'] == 'workflow' ? self.class.summary(data['source_definition']) : nil)
  end

  def self.summary(workflow)
    nodes = workflow.fetch('nodes')
    {
      node_count: nodes.size, connection_count: workflow.fetch('connections').size,
      nodes: nodes.map { |node| { name: node['name'], type: node['type'], disabled: node['disabled'] == true } },
      credentials: nodes.flat_map { |n| n.fetch('credentials', {}).keys }.uniq.sort,
      subworkflows: nodes.select { |n| n['type'] == 'n8n-nodes-base.executeWorkflow' }.map { |n| n['name'] },
      webhooks: nodes.select { |n| n['type'] == 'n8n-nodes-base.webhook' }.map do |n|
        n.fetch('parameters', {}).slice('path', 'httpMethod', 'authentication', 'responseMode')
      end
    }
  end

  private

  def validate_n8n(workflow)
    valid = workflow.is_a?(Hash) && workflow['nodes'].is_a?(Array) && workflow['nodes'].size.between?(1, 500) &&
      workflow['connections'].is_a?(Hash) && workflow['nodes'].all? do |node|
        node.is_a?(Hash) && %w[name type].all? { |key| node[key].is_a?(String) } &&
          node.fetch('parameters', {}).is_a?(Hash) && node.fetch('credentials', {}).is_a?(Hash)
      end
    raise Invalid, 'Workflow n8n inválido: confira nodes e connections (até 500 nós).' unless valid

    workflow
  end
end
