import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createEngine } from '../src/engine.ts';

test('provider dispatch validates accounting and propagates cancellation', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'nico-provider-'));
  const engine = await createEngine({ mode: 'provider', dataDir: dir, model: 'test-model', apiKey: 'test-only' });
  const original = globalThis.fetch;
  const input = { request_id: 'a56905c4-9a03-4c21-a886-b5d18a3e4c57', account_id: 1, agent_key: 'nico' as const, message: 'Resumo', history: [], context: { conversation: [], crm: [], knowledge: [] } };
  try {
    const body = { choices: [{ message: { content: JSON.stringify({ summary: 'Teste', suggested_reply: '', evidence: [], warnings: [] }) } }], usage: { prompt_tokens: 100, completion_tokens: 10, total_tokens: 0 } };
    globalThis.fetch = async () => Response.json(body);
    await assert.rejects(engine.analyze(input));
    body.usage.total_tokens = 110;
    const result = await engine.analyze(input);
    assert.equal(result.usage?.total_tokens, 110);
    let requestedFormat: any;
    globalThis.fetch = async (_url, options) => {
      requestedFormat = JSON.parse(String(options?.body)).response_format;
      return Response.json(body);
    };
    await engine.analyze(input);
    assert.equal(requestedFormat.type, 'json_schema');
    assert.equal(requestedFormat.json_schema.strict, true);
    assert.deepEqual(requestedFormat.json_schema.schema.properties.evidence.items.required, ['source', 'reference']);
    assert.equal(requestedFormat.json_schema.schema.properties.evidence.items.additionalProperties, false);
    const cancellation = new AbortController();
    let began!: () => void;
    const started = new Promise<void>(resolve => { began = resolve; });
    globalThis.fetch = async (_url, options) => new Promise((_resolve, reject) => {
      began();
      const signal = options?.signal;
      signal?.addEventListener('abort', () => reject(new Error('aborted')), { once: true });
    });
    const pending = engine.analyze(input, cancellation.signal);
    await started;
    cancellation.abort();
    await assert.rejects(pending);
  } finally {
    globalThis.fetch = original;
    await engine.close();
    await rm(dir, { recursive: true, force: true });
  }
});
