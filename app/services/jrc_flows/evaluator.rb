class JrcFlows::Evaluator
  def initialize(variables)
    @variables = variables
  end

  def render(value)
    value.to_s.gsub(/\{\{\s*([\w.]+)\s*\}\}/) { @variables[Regexp.last_match(1)].to_s }.truncate(10_000, omission: '')
  end

  def matches?(rule)
    actual = @variables[rule['field'].presence || 'message'].to_s.downcase.strip
    expected = render(rule['value']).downcase.strip
    case rule['operator']
    when 'equals' then actual == expected
    when 'not_equals' then actual != expected
    when 'contains' then actual.include?(expected)
    when 'starts_with' then actual.start_with?(expected)
    when 'present' then actual.present?
    else false
    end
  end

  def port(node)
    return matches?(node['data']) ? 'yes' : 'no' if node['type'] == 'condition'

    node['data'].fetch('cases', []).find { |rule| matches?(rule) }&.fetch('id') || 'fallback'
  end
end
