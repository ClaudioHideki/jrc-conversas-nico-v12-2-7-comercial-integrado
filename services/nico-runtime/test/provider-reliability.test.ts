import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { structuredResponse } from '../src/provider.ts';
import { NicoError, errorResponse } from '../src/errors.ts';
import { parseToolArguments, validateOperationResult } from '../src/operations.ts';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/operation-contract.json', import.meta.url), 'utf8'));
const valid = { reply: fixture.reply, tool: fixture.tool, arguments: fixture.arguments };
const envelope = (output: unknown) => Response.json({ choices: [{ message: { content: JSON.stringify(output) } }],
  usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 } });
const options = { url: 'https://provider.invalid/chat/completions', apiKey: 'PRIVATE_API_KEY_TEST', retryInvalid: true,
  body: { model: 'test-model', max_completion_tokens: 2000, messages: [{ role: 'user', content: 'PRIVATE_CONTEXT_TEST' }] },
  validate: (value: unknown) => validateOperationResult(value, 'operator') };

test('valid first response matches the shared Ruby wire contract', async t => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => envelope(valid));
  const response = await structuredResponse(options);
  assert.deepEqual(response.result, valid);
  assert.deepEqual(parseToolArguments(response.result.arguments), JSON.parse(fixture.arguments));
  assert.equal(fetch.mock.callCount(), 1);
});

test('invalid inner JSON retries once with identical context, then returns one intact action', async t => {
  const requests: any[] = [];
  const signals: any[] = [];
  t.mock.method(globalThis, 'fetch', async (_url, init) => {
    requests.push(JSON.parse(init.body)); signals.push(init.signal);
    return envelope(requests.length === 1 ? { ...valid, arguments: '{"phone_number":+5511991234567}' } : valid);
  });
  const response = await structuredResponse(options);
  assert.deepEqual(response.result, valid);
  assert.equal(requests.length, 2);
  assert.deepEqual(requests[1].messages.slice(0, -1), requests[0].messages);
  assert.match(requests[1].messages.at(-1).content, /objeto JSON válido/);
  assert.equal(signals[0], signals[1]);
  assert.equal(response.usage.total_tokens, 30);
  assert.equal(response.usageEstimated, false);
});

test('two invalid answers return a controlled code and never expose an action', async t => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => envelope({ ...valid, arguments: '{' }));
  let executable = 0;
  await assert.rejects(structuredResponse(options).then(() => { executable += 1; }), { code: 'tool_arguments_invalid', name: 'NicoError' });
  assert.equal(executable, 0);
  assert.equal(fetch.mock.callCount(), 2);
});

test('outer JSON and schema errors are distinct; outer envelope failure charges marked estimated usage', async t => {
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => ++calls === 1 ? new Response('PRIVATE_MALFORMED_BODY') : envelope(valid));
  const response = await structuredResponse(options);
  assert.equal(calls, 2);
  assert.equal(response.usageEstimated, true);
  assert.ok(response.usage.total_tokens > 12000);
  for (const [output, code] of [[[], 'provider_schema_invalid'], [{ ...valid, unexpected: true }, 'provider_schema_invalid']]) {
    t.mock.method(globalThis, 'fetch', async () => envelope(output));
    await assert.rejects(structuredResponse(options), { code });
  }
  t.mock.method(globalThis, 'fetch', async () => Response.json({ choices: [{ message: { content: '{' } }], usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 } }));
  await assert.rejects(structuredResponse(options), { code: 'provider_outer_json_invalid' });
});

test('arguments reject arrays, primitives, excessive bytes/depth and unsafe numbers without repairs', () => {
  for (const value of ['[1]', 'null', 'false', '42', '"text"', '{', '{"id":9007199254740993}', '{"value":1e999}',
    JSON.stringify({ content: 'á'.repeat(6000) }), '{"x":'.repeat(9) + '0' + '}'.repeat(9)]) {
    assert.throws(() => parseToolArguments(value), { code: 'tool_arguments_invalid' });
  }
  assert.deepEqual(parseToolArguments('{"id":123,"phone":"+5511991234567","date":"2026-09-15T10:00:00-03:00"}'),
    { id: 123, phone: '+5511991234567', date: '2026-09-15T10:00:00-03:00' });
});

for (const [status, code] of [[401, 'provider_unauthorized'], [403, 'provider_forbidden'], [429, 'provider_rate_limited'],
  [500, 'provider_unavailable'], [503, 'provider_unavailable']] as const) {
  test(`HTTP ${status} has stable code and never retries`, async t => {
    const fetch = t.mock.method(globalThis, 'fetch', async () => new Response('PRIVATE_API_KEY_TEST', { status }));
    await assert.rejects(structuredResponse(options), { code });
    assert.equal(fetch.mock.callCount(), 1);
  });
}

test('timeout covers retry and response-body wait; cancellation stops all attempts', async t => {
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async (_url, init) => {
    if (++calls === 1) return envelope({ ...valid, arguments: '{' });
    return new Promise((_resolve, reject) => init.signal.addEventListener('abort', () => reject(init.signal.reason), { once: true }));
  });
  const keepAlive = setTimeout(() => {}, 1000);
  try { await assert.rejects(structuredResponse({ ...options, timeoutMs: 20 }), { code: 'provider_timeout' }); }
  finally { clearTimeout(keepAlive); }
  assert.equal(calls, 2);
  const cancellation = new AbortController(); cancellation.abort();
  await assert.rejects(structuredResponse({ ...options, signal: cancellation.signal }), { code: 'request_cancelled' });
  assert.equal(calls, 2);
});

test('logs are an allowlist and never contain exceptions, credentials, headers or conversation text', () => {
  const privateText = 'Authorization Bearer PRIVATE_API_KEY_TEST NICO_SERVICE_TOKEN PRIVATE_CONTEXT_TEST';
  const unknown = errorResponse(new Error(privateText), '/v1/operate');
  assert.deepEqual(unknown.log, { event: 'nico_request_failed', route: '/v1/operate', code: 'runtime_internal_error' });
  assert.equal(JSON.stringify(unknown).includes(privateText), false);
  assert.equal(errorResponse(new NicoError('runtime_busy'), '/v1/operate').status, 429);
});

test('repeated read requests preserve count/list without query and real conversation filters', async t => {
  const scenarios = [['Quantos contatos temos cadastrados?', 'count_contacts', {}], ['Liste meus contatos cadastrados.', 'list_contacts', {}],
    ['Liste as conversas abertas recentes.', 'list_conversations', { status: 'open' }],
    ['Quais conversas estão aguardando atendimento?', 'list_conversations', { status: 'pending' }]] as const;
  for (let run = 0; run < 5; run++) {
    for (const [message, tool, args] of scenarios) {
      t.mock.method(globalThis, 'fetch', async () => envelope({ reply: '', tool, arguments: JSON.stringify(args) }));
      const response = await structuredResponse({ ...options, body: { ...options.body, messages: [{ role: 'user', content: message }] } });
      assert.equal(response.result.tool, tool);
      assert.deepEqual(parseToolArguments(response.result.arguments), args);
    }
  }
});
