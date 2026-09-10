import { readFile, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import assert from 'node:assert/strict';

const mode = process.argv[2] || 'inspect';
assert.ok(['prepare', 'inspect', 'approve', 'verify', 'timezone'].includes(mode));
const config = JSON.parse(await readFile('local/nico-customer-simulator.json', 'utf8'));
const env = await readFile('local/nico.env', 'utf8');
const password = env.match(/^NICO_LOCAL_PASSWORD=(.+)$/m)[1].trim();
const headers = { 'Content-Type': 'application/json' };
const base = 'http://localhost:3000';
const operations = '/api/v1/accounts/1/jrc_nico/operations';
const file = 'docs/validation/nico-notices-e2e.json';
const report = mode === 'prepare' ? { at: new Date().toISOString(), approved: [] } : JSON.parse(await readFile(file, 'utf8'));
async function request(method, path, input, anonymous = false) {
  const response = await fetch(base + path, { method,
    headers: anonymous ? { 'Content-Type': 'application/json' } : headers,
    body: input ? JSON.stringify(input) : undefined, signal: AbortSignal.timeout(180000),
  });
  if (!anonymous) for (const key of ['access-token', 'client', 'uid', 'token-type']) {
    if (response.headers.get(key)) headers[key] = response.headers.get(key);
  }
  const data = await response.json();
  assert.ok(response.ok, method + ' ' + path + ': HTTP ' + response.status);
  return data;
}
async function snapshot() {
  const state = await request('GET', operations);
  const events = await request('GET', operations + '/notices');
  return { state, notices: events.notices.filter(n => n.conversation_id === config.conversation_id) };
}
try {
  await request('POST', '/auth/sign_in', { email: 'admin@gopure.test', password });
  if (mode === 'timezone') {
    const state = await request('POST', operations + '/prepare', {
      request_id: randomUUID(), message: 'Usar horário de Brasília na agenda da homologação local',
      tool: 'set_reporting_timezone', arguments: { timezone: 'America/Sao_Paulo' },
    });
    const command = state.commands.find(c => c.tool === 'set_reporting_timezone' && c.status === 'awaiting_confirmation');
    assert.ok(command);
    const result = await request('POST', operations + '/commands/' + command.id + '/confirm');
    report.timezone_command = result.commands.find(c => c.id === command.id);
    assert.equal(report.timezone_command.status, 'succeeded');
  }
  if (mode === 'prepare') {
    const before = await snapshot();
    assert.equal(before.state.delegations.find(d => d.conversation_id === config.conversation_id)?.status, 'active');
    report.baseline_notice_ids = before.notices.map(n => n.id);
    const message = await request('POST', config.customer_path + '/messages', {
      content: 'Marina aqui. Meu email para contato é marina.nico.local@example.test. Quero uma reunião de demonstração amanhã às 15h, horário de Brasília. Atualize meu email no cadastro e registre esse agendamento no CRM, por favor. A reunião é sobre atendimento da nossa equipe de 10 operadores.',
      echo_id: randomUUID(),
    }, true);
    report.incoming_id = message.id;
    const deadline = Date.now() + 120000;
    while (Date.now() < deadline) {
      const current = await snapshot();
      const notice = current.notices.find(n => n.kind === 'action' && !report.baseline_notice_ids.includes(n.id));
      if (notice) {
        report.notice_id = notice.id;
        const commands = current.state.commands.filter(c => c.source_notice_id === notice.id);
        if (commands.some(c => c.status === 'awaiting_confirmation') || ['failed', 'review'].includes(notice.status)) {
          report.initial_notice = notice;
          report.initial_commands = commands;
          console.log(JSON.stringify({ notice, commands }));
          break;
        }
      }
      await delay(2000);
    }
    assert.ok(report.notice_id, 'Necessidade do cliente deve gerar aviso');
  }
  if (mode === 'approve') {
    const deadline = Date.now() + 120000;
    while (Date.now() < deadline) {
      const current = await snapshot();
      const commands = current.state.commands.filter(c => c.source_notice_id === report.notice_id);
      const next = commands.find(c => c.status === 'awaiting_confirmation');
      if (next) {
        assert.ok(['update_contact', 'create_activity', 'create_lead', 'update_lead'].includes(next.tool), 'Ação fora do teste local: ' + next.tool);
        if (next.arguments.contact_id) assert.equal(next.arguments.contact_id, config.contact_id);
        assert.ok(report.approved.length < 5, 'Teste limitado a cinco ações');
        const approved = await request('POST', operations + '/commands/' + next.id + '/confirm');
        const result = approved.commands.find(c => c.id === next.id);
        assert.equal(result.status, 'succeeded', result.reply);
        report.approved.push({ id: next.id, tool: next.tool, result: result.result });
        console.log(JSON.stringify(report.approved.at(-1)));
      } else if (commands.length && !commands.some(c => ['planning', 'executing', 'browser_pending'].includes(c.status))) {
        const notice = current.notices.find(n => n.id === report.notice_id);
        if (['review', 'failed', 'cancelled'].includes(notice?.status)) break;
      }
      await delay(2500);
    }
  }
  const current = await snapshot();
  report.notice = current.notices.find(n => n.id === report.notice_id);
  report.commands = current.state.commands.filter(c => c.source_notice_id === report.notice_id);
  report.contact = (await request('GET', '/api/v1/accounts/1/contacts/' + config.contact_id)).payload;
  const messages = await request('GET', config.customer_path + '/messages', undefined, true);
  report.customer_replies = messages.filter(m => m.id > report.incoming_id && m.message_type === 1 && m.content_attributes?.nico_delegation)
    .map(m => ({ id: m.id, content: m.content }));
  if (mode === 'verify') {
    report.passed = false;
    assert.equal(report.contact.email, 'marina.nico.local@example.test');
    const activities = report.commands.filter(c => c.tool === 'create_activity' && c.status === 'succeeded');
    assert.equal(activities.length, 1, 'Uma única atividade deve ter sido criada');
    report.activity = await request('GET', '/api/v1/accounts/1/crm/activities/' + activities[0].result.record.id);
    assert.equal(report.activity.lead_id, activities[0].arguments.lead_id);
    assert.equal(report.activity.due_at_display, '11/09/2026 15:00');
    assert.equal(new Date(report.activity.due_at).getTime(), new Date('2026-09-11T15:00:00-03:00').getTime());
    assert.equal(report.activity.status, 'scheduled');
    assert.ok(report.customer_replies.length);
    for (const reply of report.customer_replies) assert.doesNotMatch(reply.content, /^(olá|oi|bom dia|boa tarde|boa noite)\b/i);
    report.passed = true;
    report.verified_at = new Date().toISOString();
  }
  console.log(JSON.stringify({ notice: report.notice, commands: report.commands.map(c => ({ id: c.id, tool: c.tool, status: c.status, reply: c.reply, arguments: c.arguments })),
    customer_replies: report.customer_replies, passed: report.passed }));
} finally {
  await writeFile(file, JSON.stringify(report, null, 2));
  if (headers['access-token']) await fetch(base + '/auth/sign_out', { method: 'DELETE', headers }).catch(() => {});
}
