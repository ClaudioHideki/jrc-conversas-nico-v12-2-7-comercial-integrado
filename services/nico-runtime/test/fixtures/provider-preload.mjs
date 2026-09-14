// Only loaded explicitly by the HTTP integration test via node --import.
globalThis.fetch = async (_url, options) => {
  const payload = JSON.parse(options.body);
  const input = JSON.parse(payload.messages[1].content);
  if (input.message === 'rate_limit') return new Response('PRIVATE_PROVIDER_BODY', { status: 429 });
  const args = input.message === 'valid_second' && payload.messages.length > 2 ? '{}' : '{PRIVATE_CONVERSATION';
  return Response.json({ choices: [{ message: { content: JSON.stringify({ reply: 'Consulta pronta', tool: 'count_contacts', arguments: args }) } }],
    usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 } });
};
