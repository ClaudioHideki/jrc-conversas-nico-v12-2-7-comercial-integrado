import { readFile, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import assert from 'node:assert/strict';

const base = 'http://localhost:3000';
const env = await readFile(new URL('../local/nico.env', import.meta.url), 'utf8');
const password = env.match(/^NICO_LOCAL_PASSWORD=(.+)$/m)?.[1].trim();
const sessions = [];
const report = { at: new Date().toISOString(), passed: false, scenarios: [], runs: [], checks: {} };
async function request(headers, method, path, input, expected = 200) {
  const response = await fetch(base + path, {
    method, headers, body: input ? JSON.stringify(input) : undefined,
    signal: AbortSignal.timeout(60000),
  });
  for (const key of ['access-token', 'client', 'uid', 'token-type']) {
    if (response.headers.get(key)) headers[key] = response.headers.get(key);
  }
  assert.equal(response.status, expected, `${method} ${path}: HTTP ${response.status}`);
  return response.json();
}
async function login(email) {
  const headers = { 'Content-Type': 'application/json' };
  await request(headers, 'POST', '/auth/sign_in', { email, password });
  sessions.push(headers);
  return headers;
}
try {
  const admin = await login('admin@gopure.test');
  const operator = await login('operator@gopure.test');
  const isolated = await login('admin@isolada.test');
  report.checks.three_logins = true;
  for (const path of ['knowledge_documents', 'erp?conversation_id=3']) {
    await request(operator, 'GET', `/api/v1/accounts/1/jrc_nico/${path}`, undefined, 403);
  }
  await request(operator, 'GET', '/api/v1/accounts/1/jrc_campaigns/campaigns', undefined, 403);
  await request(isolated, 'GET', '/api/v1/accounts/1/jrc_nico/assistance?conversation_id=3', undefined, 401);
  report.checks.operator_restrictions = true;
  report.checks.account_isolation = true;
  const before = {};
  for (let id = 1; id <= 6; id++) {
    before[id] = (await request(admin, 'GET', `/api/v1/accounts/1/conversations/${id}/messages`)).payload.map(x => x.id);
    const assistance = await request(admin, 'GET', `/api/v1/accounts/1/jrc_nico/assistance?conversation_id=${id}`);
    assert.equal(assistance.agents.length, 7);
    report.scenarios.push({ conversation_id: id, agent: assistance.recommendation.agent_key, status: assistance.recommendation.status, lead_id: assistance.lead?.id });
    if (id >= 2) assert.equal(assistance.recommendation.agent_key, { 2: 'comercial', 3: 'suporte_n1', 4: 'financeiro', 5: 'implantacao', 6: 'cx' }[id]);
  }
  report.checks.five_intents = true;
  const erp = await request(admin, 'GET', '/api/v1/accounts/1/jrc_nico/erp?conversation_id=3');
  assert.equal(erp.settings.mode, 'live');
  assert.equal(erp.binding.mode, 'live');
  assert.equal(erp.external_writes_enabled, false);
  report.checks.erp_live_read_only = true;
  const path = '/api/v1/accounts/1/jrc_nico/runs';
  const scenarios = [['nico', 1], ['comercial', 2], ['suporte_n1', 3], ['financeiro', 4], ['implantacao', 5], ['cx', 6], ['supervisor', 1]];
  for (const [agent, conversation] of scenarios) {
    const input = { agent_key: agent, conversation_id: conversation, request_id: randomUUID(), message: 'Validação local assistida. Resuma o pedido, use somente as fontes autorizadas, cite também o lead CRM quando houver, identifique pendências e sugira uma resposta curta para revisão humana. Não afirme ter enviado mensagens ou executado ações externas.' };
    let run = await request(admin, 'POST', path, input, 202);
    const duplicate = await request(admin, 'POST', path, input, 202);
    assert.equal(duplicate.id, run.id);
    await request(admin, 'POST', path, { ...input, message: 'Pedido diferente com a mesma chave' }, 409);
    const deadline = Date.now() + 150000;
    while (['queued', 'running'].includes(run.status) && Date.now() < deadline) {
      await delay(1000);
      run = await request(admin, 'GET', `${path}/${run.id}`);
    }
    assert.equal(run.status, 'completed', `${agent}: ${run.status}/${run.error_code}`);
    assert.equal(run.agent_key, agent);
    assert.equal(run.result.mode, 'provider');
    assert.ok(run.result.usage.total_tokens > 0);
    assert.ok(run.result.summary && run.result.suggested_reply);
    const sources = [...new Set(run.result.evidence.map(x => x.source))];
    if (['suporte_n1', 'financeiro'].includes(agent)) assert.ok(sources.includes('erp'), `${agent}: ERP reference absent`);
    report.runs.push({ agent, conversation_id: conversation, run_id: run.id, status: run.status, model: run.result.model, total_tokens: run.result.usage.total_tokens, sources, warnings: run.result.warnings });
    if (agent === 'comercial') {
      const lead = run.result.evidence.find(x => x.source === 'crm' && x.reference.startsWith('lead:'));
      assert.ok(lead, 'Commercial CRM reference absent');
      const proposal = await request(admin, 'POST', '/api/v1/accounts/1/jrc_nico/proposals', {
        run_id: run.id, lead_id: Number(lead.reference.split(':')[1]), request_id: randomUUID(),
        title: 'Validação local — retorno comercial', due_at: new Date(Date.now() + 86400000).toISOString(),
      }, 201);
      assert.equal(proposal.status, 'pending');
      assert.equal(proposal.activity_id, null);
      const approvalPath = `/api/v1/accounts/1/jrc_nico/proposals/${proposal.id}/approve`;
      await request(admin, 'POST', approvalPath, { digest: 'invalid-review' }, 409);
      const approved = await request(admin, 'POST', approvalPath, { digest: proposal.digest });
      const repeated = await request(admin, 'POST', approvalPath, { digest: proposal.digest });
      assert.equal(approved.status, 'executed');
      assert.ok(approved.activity_id);
      assert.equal(approved.activity_id, repeated.activity_id);
      report.checks.crm_approved_once = { proposal_id: proposal.id, activity_id: approved.activity_id };
    }
    console.log(`${agent}: completed (run ${run.id}, ${run.result.usage.total_tokens} tokens)`);
  }
  const ownRun = report.runs[0].run_id;
  await request(operator, 'GET', `${path}/${ownRun}`, undefined, 404);
  report.checks.run_user_isolation = true;
  for (let id = 1; id <= 6; id++) {
    const after = (await request(admin, 'GET', `/api/v1/accounts/1/conversations/${id}/messages`)).payload.map(x => x.id);
    assert.deepEqual(after, before[id], `Conversation ${id}: messages changed`);
  }
  report.checks.public_messages_unchanged = true;
  report.checks.run_idempotency = true;
  report.total_tokens = report.runs.reduce((sum, run) => sum + run.total_tokens, 0);
  report.passed = true;
} catch (error) {
  report.error = error.message;
  process.exitCode = 1;
} finally {
  await writeFile(new URL('../docs/validation/nico-revalidation-local-20260908.json', import.meta.url), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
  for (const headers of sessions) await fetch(base + '/auth/sign_out', { method: 'DELETE', headers, signal: AbortSignal.timeout(15000) }).catch(() => {});
}
