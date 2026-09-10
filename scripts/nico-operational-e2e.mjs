import { readFile, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import assert from 'node:assert/strict';
const base = 'http://localhost:3000';
const env = await readFile(new URL('../local/nico.env', import.meta.url), 'utf8');
const password = env.match(/^NICO_LOCAL_PASSWORD=(.+)$/m)[1].trim();
const headers = { 'Content-Type': 'application/json' };
const path = '/api/v1/accounts/1/jrc_nico/operations';
const report = { at: new Date().toISOString(), commands: [], customers: [] };
const ids = JSON.parse(await readFile(new URL('../local/nico-qa-conversations.json', import.meta.url), 'utf8'));
async function request(method, route, input) {
  const response = await fetch(base + route, { method, headers, body: input ? JSON.stringify(input) : undefined, signal: AbortSignal.timeout(210000) });
  for (const key of ['access-token', 'client', 'uid', 'token-type']) if (response.headers.get(key)) headers[key] = response.headers.get(key);
  const data = await response.json();
  assert.ok(response.ok, `${method} ${route}: HTTP ${response.status} ${data.error || ''}`);
  return data;
}
async function ask(message) {
  const data = await request('POST', path + '/ask', { request_id: randomUUID(), message });
  console.log(JSON.stringify({ step: 'operator', reply: data.messages.at(-1)?.content, command: data.commands[0]?.tool, status: data.commands[0]?.status }));
  return data.commands[0];
}
async function approve(command, tool) {
  assert.equal(command.tool, tool);
  assert.equal(command.status, 'awaiting_confirmation');
  const state = await request('POST', `${path}/commands/${command.id}/confirm`);
  const result = state.commands.find(c => c.id === command.id);
  assert.equal(result.status, 'succeeded', result.reply);
  report.commands.push({ tool, command_id: command.id, result: result.result });
  console.log(JSON.stringify({ step: 'confirmed', tool, result: result.result }));
  return result.result;
}
try {
  await request('POST', '/auth/sign_in', { email: 'admin@gopure.test', password });
  const stamp = Date.now().toString().slice(-7);
  let command = await ask('Quero criar um contato novo. Pergunte os dados necessários.');
  assert.notEqual(command.status, 'awaiting_confirmation');
  command = await ask(`Nome: Teste NICO Operador ${stamp}. Email: nico-operador-${stamp}@example.test. Não tem telefone.`);
  const contact = await approve(command, 'create_contact');
  const contactId = contact.record.id;
  const verifiedContact = await request('GET', `/api/v1/accounts/1/contacts/${contactId}`);
  assert.ok(JSON.stringify(verifiedContact).includes(`Teste NICO Operador ${stamp}`));
  command = await ask('Transforme esse contato que acabamos de cadastrar em um lead comercial.');
  const lead = await approve(command, 'create_lead');
  assert.equal(lead.record.contact_id, contactId);
  command = await ask(`Crie uma atividade do tipo tarefa para este lead ${lead.record.id}, título "Retorno NICO QA", amanhã às 10h. Não envie mensagens.`);
  await approve(command, 'create_activity');
  let state = await request('POST', path + '/prepare', { request_id: randomUUID(), message: 'Homologação: atender três clientes fictícios', tool: 'delegate_conversations', arguments: {
    conversation_ids: ids.map(c => c.conversation_id), objective: 'Apresente-se como assistente virtual e pergunte qual solução e quantidade o cliente procura. Somente qualificação, sem preços ou compromissos.', hours: 1, allow_crm: false,
  } });
  await approve(state.commands[0], 'delegate_conversations');
  const deadline = Date.now() + 150000;
  while (Date.now() < deadline && report.customers.length < ids.length) {
    for (const client of ids) {
      if (report.customers.some(c => c.conversation_id === client.conversation_id)) continue;
      const messages = await request('GET', `/api/v1/accounts/1/conversations/${client.conversation_id}/messages`);
      const reply = messages.payload.find(m => m.content_attributes?.nico_delegation);
      if (reply) {
        assert.ok(reply.content?.length > 10);
        report.customers.push({ conversation_id: client.conversation_id, message_id: reply.id, reply: reply.content, state: reply.status });
        console.log(JSON.stringify({ step: 'customer_replied', ...report.customers.at(-1) }));
      }
    }
    if (report.customers.length < ids.length) await delay(3000);
  }
  assert.equal(report.customers.length, 3, 'Os três clientes fictícios devem receber resposta do NICO');
  report.passed = true;
} catch (e) {
  report.passed = false;
  report.error = e.message;
  console.error(JSON.stringify({ passed: false, error: e.message }));
  process.exitCode = 1;
} finally {
  if (headers['access-token']) {
    for (const client of ids) await request('POST', path + '/takeover', { conversation_id: client.conversation_id }).catch(() => {});
    await fetch(base + '/auth/sign_out', { method: 'DELETE', headers }).catch(() => {});
  }
  await writeFile(new URL('../docs/validation/nico-operational-e2e.json', import.meta.url), JSON.stringify(report, null, 2));
}
