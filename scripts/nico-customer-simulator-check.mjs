import { readFile, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import assert from 'node:assert/strict';

// Run inside the local web container. Never prints authentication/provider credentials.
const mode = process.argv[2] || 'inspect';
assert.ok(['delegate', 'delegate-crm', 'inspect', 'verify-human', 'verify-handoff'].includes(mode));
const config = JSON.parse(await readFile('local/nico-customer-simulator.json', 'utf8'));
const env = await readFile('local/nico.env', 'utf8');
const password = env.match(/^NICO_LOCAL_PASSWORD=(.+)$/m)[1].trim();
const base = 'http://localhost:3000';
const operations = '/api/v1/accounts/1/jrc_nico/operations';
const headers = { 'Content-Type': 'application/json' };
async function request(method, path, input, publicRequest = false) {
  const response = await fetch(base + path, {
    method, headers: publicRequest ? { 'Content-Type': 'application/json' } : headers,
    body: input ? JSON.stringify(input) : undefined, signal: AbortSignal.timeout(30000),
  });
  if (!publicRequest) for (const key of ['access-token', 'client', 'uid', 'token-type']) {
    if (response.headers.get(key)) headers[key] = response.headers.get(key);
  }
  assert.ok(response.ok, method + ' ' + path + ': HTTP ' + response.status);
  return response.json();
}
const delegation = state => state.delegations.find(item => item.conversation_id === config.conversation_id);
try {
  await request('POST', '/auth/sign_in', { email: 'admin@gopure.test', password });
  let state = await request('GET', operations);
  if (['delegate', 'delegate-crm'].includes(mode)) {
    assert.ok(!state.commands.some(command => ['planning', 'awaiting_confirmation', 'browser_pending', 'executing'].includes(command.status)),
      'Há um pedido pendente do operador; não substituir durante o teste.');
    if (mode === 'delegate-crm' && delegation(state)?.status === 'active') {
      state = await request('POST', operations + '/takeover', { conversation_id: config.conversation_id });
    }
    state = await request('POST', operations + '/prepare', {
      request_id: randomUUID(), message: 'Teste local: NICO, atenda Marina — Cliente Simulado na conversa #' + config.conversation_id,
      tool: 'delegate_conversations', arguments: {
        conversation_ids: [config.conversation_id], hours: 2, allow_crm: mode === 'delegate-crm',
        objective: 'Atenda Marina, cliente fictícia da Loja Horizonte. Apresente-se como assistente virtual. Qualifique sua necessidade de atendimento comercial: canais, tamanho da equipe, dificuldade atual e prazo. Explique somente capacidades documentadas de conversas, contatos e CRM. Não invente preços, promessas ou agendamentos. Mantenha o diálogo enquanto ela quiser esclarecer suas necessidades; encaminhe ao humano quando solicitado ou faltar informação comercial.',
      },
    });
    const command = state.commands[0];
    assert.equal(command.tool, 'delegate_conversations');
    assert.equal(command.status, 'awaiting_confirmation');
    state = await request('POST', operations + '/commands/' + command.id + '/confirm');
    assert.equal(state.commands.find(item => item.id === command.id).status, 'succeeded');
    assert.equal(delegation(state).status, 'active');
    console.log(JSON.stringify({ step: 'delegated', command_id: command.id, delegation: delegation(state) }));
  }
  if (mode === 'verify-human') {
    state = await request('POST', operations + '/takeover', { conversation_id: config.conversation_id });
    assert.equal(delegation(state).status, 'paused');
    const incoming = await request('POST', config.customer_path + '/messages', {
      content: 'Teste de retomada: estou aguardando o atendente humano. Minha equipe tem 10 operadores.',
      echo_id: randomUUID(),
    }, true);
    await delay(10000);
    const messages = await request('GET', config.customer_path + '/messages', undefined, true);
    assert.ok(!messages.some(message => message.id > incoming.id && message.content_attributes?.nico_delegation),
      'NICO não deve responder após retomada humana');
    state = await request('GET', operations);
    assert.equal(delegation(state).status, 'paused');
    await writeFile('docs/validation/nico-customer-simulator-human.json', JSON.stringify({
      at: new Date().toISOString(), passed: true, incoming_id: incoming.id,
      observed_seconds: 10, delegation: delegation(state),
    }, null, 2));
    console.log(JSON.stringify({ step: 'human_takeover_verified', incoming_id: incoming.id, observed_seconds: 10 }));
  }
  if (mode === 'verify-handoff') {
    const deadline = Date.now() + 60000;
    while (delegation(state).status === 'active' && Date.now() < deadline) {
      await delay(2000);
      state = await request('GET', operations);
    }
    assert.equal(delegation(state).status, 'needs_human');
    const messages = await request('GET', config.customer_path + '/messages', undefined, true);
    const reply = messages.filter(message => message.message_type === 1).sort((a, b) => b.id - a.id)[0];
    assert.equal(reply.content_attributes?.nico_delegation?.handoff, true);
    assert.match(reply.content, /humano/i);
    await writeFile('docs/validation/nico-customer-simulator-handoff.json', JSON.stringify({
      at: new Date().toISOString(), passed: true, delegation: delegation(state), reply_id: reply.id, reply: reply.content,
    }, null, 2));
    console.log(JSON.stringify({ step: 'customer_handoff_verified', reply_id: reply.id, reply: reply.content }));
  }
  const messages = await request('GET', config.customer_path + '/messages', undefined, true);
  const result = {
    at: new Date().toISOString(), conversation_id: config.conversation_id,
    delegation: delegation(state),
    messages: messages.filter(message => [0, 1].includes(message.message_type)).sort((a, b) => a.id - b.id).map(message => ({
      id: message.id, type: message.message_type, content: message.content,
      sender_type: message.sender?.type, delegation: message.content_attributes?.nico_delegation,
      turn_id: message.content_attributes?.nico_turn_id,
    })),
  };
  await writeFile('docs/validation/nico-customer-simulator.json', JSON.stringify(result, null, 2));
  console.log(JSON.stringify({ at: result.at, conversation_id: result.conversation_id,
    status: result.delegation?.status, reason: result.delegation?.reason, expires_at: result.delegation?.expires_at,
    public_messages: result.messages.length, latest: result.messages.slice(-2) }));
} finally {
  if (headers['access-token']) await fetch(base + '/auth/sign_out', { method: 'DELETE', headers }).catch(() => {});
}
