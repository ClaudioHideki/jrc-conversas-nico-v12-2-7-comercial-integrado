import { readFile, writeFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';

const base = process.env.NICO_SMOKE_URL || 'http://localhost:3107';
assert.ok(['http://localhost:3107', 'http://gateway:3107'].includes(base), 'Local fixture only');
const env = await readFile(new URL('../local/nico.env', import.meta.url), 'utf8');
const password = env.match(/^NICO_LOCAL_PASSWORD=(.+)$/m)?.[1].trim();
assert.ok(password, 'Generate the local environment first');
const results = [];
const sessions = [];

async function login(email) {
  const response = await fetch(`${base}/auth/sign_in`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }), signal: AbortSignal.timeout(60000) });
  assert.equal(response.status, 200, `Local login failed: ${email}`);
  const headers = { 'Content-Type': 'application/json' };
  for (const name of ['access-token', 'client', 'uid', 'token-type']) headers[name] = response.headers.get(name);
  assert.ok(headers['access-token'], 'Authentication token missing');
  sessions.push(headers);
  return headers;
}
async function request(headers, method, path, input, expected = 200) {
  const response = await fetch(`${base}${path}`, { method, headers, ...(input ? { body: JSON.stringify(input) } : {}), signal: AbortSignal.timeout(60000) });
  for (const name of ['access-token', 'client', 'uid', 'token-type']) if (response.headers.get(name)) headers[name] = response.headers.get(name);
  assert.equal(response.status, expected, `${method} ${path} returned ${response.status}`);
  return response.json();
}
async function analyze(headers, accountId) {
  const path = `/api/v1/accounts/${accountId}/jrc_nico/runs`;
  const input = { request_id: randomUUID(), conversation_id: 1, message: 'implantação suporte' };
  let run = await request(headers, 'POST', path, input, 202);
  const duplicate = await request(headers, 'POST', path, input, 202);
  assert.equal(duplicate.id, run.id, 'Duplicate inference created');
  await request(headers, 'POST', path, { ...input, message: 'outro pedido' }, 409);
  const deadline = Date.now() + 90000;
  while (['queued', 'running'].includes(run.status) && Date.now() < deadline) {
    await delay(750);
    run = await request(headers, 'GET', `${path}/${run.id}`);
  }
  assert.equal(run.status, 'completed', `Queue/runtime did not complete (${run.error_code})`);
  assert.equal(run.result.mode, 'fixture', 'Real provider is outside this local test');
  assert.equal(run.result.usage, null);
  assert.ok(run.result.evidence.some(item => item.source === 'conversation'));
  results.push({ account_id: accountId, run_id: run.id, status: run.status, mode: run.result.mode, evidence: run.result.evidence });
  return run;
}
try {
  const first = await login('admin@gopure.test');
  const before = await request(first, 'GET', '/api/v1/accounts/1/conversations/1/messages');
  const run = await analyze(first, 1);
  const second = await login('admin@isolada.test');
  await request(second, 'GET', `/api/v1/accounts/1/jrc_nico/runs/${run.id}`, undefined, 401);
  await analyze(second, 2);
  const lead = run.result.evidence.find(item => item.source === 'crm' && item.reference.startsWith('lead:'));
  assert.ok(lead, 'Authorized CRM context missing');
  const proposal = await request(first, 'POST', '/api/v1/accounts/1/jrc_nico/proposals', { run_id: run.id, lead_id: Number(lead.reference.split(':')[1]), request_id: randomUUID(), title: 'Retorno sintético aprovado na homologação', due_at: new Date(Date.now() + 3600000).toISOString() }, 201);
  assert.equal(proposal.status, 'pending');
  assert.equal(proposal.activity_id, null);
  const approved = await request(first, 'POST', `/api/v1/accounts/1/jrc_nico/proposals/${proposal.id}/approve`, { digest: proposal.digest });
  const again = await request(first, 'POST', `/api/v1/accounts/1/jrc_nico/proposals/${proposal.id}/approve`, { digest: proposal.digest });
  assert.equal(approved.status, 'executed');
  assert.ok(approved.activity_id);
  assert.equal(approved.activity_id, again.activity_id);
  const after = await request(first, 'GET', '/api/v1/accounts/1/conversations/1/messages');
  assert.deepEqual(after.payload.map(item => item.id), before.payload.map(item => item.id), 'A public conversation message was created');
  const operator = await login('operator@gopure.test');
  await request(operator, 'GET', '/api/v1/accounts/1/jrc_nico/knowledge_documents', undefined, 403);
  await request(operator, 'GET', '/api/v1/accounts/1/jrc_campaigns/campaigns', undefined, 403);
  const report = { passed: true, at: new Date().toISOString(), mode: 'fixture', results, proposal_id: proposal.id, activity_id: approved.activity_id, isolation: true, operator_restrictions: true, public_messages_unchanged: true };
  await writeFile(new URL('../docs/validation/local-smoke-20260907.json', import.meta.url), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
} finally {
  for (const headers of sessions) await fetch(`${base}/auth/sign_out`, { method: 'DELETE', headers, signal: AbortSignal.timeout(15000) }).catch(() => {});
}
