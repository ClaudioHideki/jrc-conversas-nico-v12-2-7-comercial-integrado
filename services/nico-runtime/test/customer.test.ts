import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createEngine } from '../src/engine.ts';

const input = { request_id: 'a56905c4-9a03-4c21-a886-b5d18a3e4c57', account_id: 1, kind: 'operator' as const, message: 'Crie um contato', history: [], context: {} };
test('customer handoff request remains the final turn after earlier commercial context', { timeout: 60000 }, async () => {
  const dir = await mkdtemp(join(tmpdir(), 'nico-customer-current-'));
  const engine = await createEngine({ mode: 'provider', dataDir: dir, model: 'test-model', apiKey: 'test-only' });
  const original = globalThis.fetch;
  const customer = {
    ...input, kind: 'customer' as const, message: 'Quero conversar com um atendente humano, por favor.',
    context: { objective: 'Qualifique a necessidade comercial', conversation: [
      { role: 'customer', content: 'Tenho interesse em comprar para 10 operadores.' },
      { role: 'assistant', content: 'Qual é seu prazo?' },
    ] },
  };
  try {
    globalThis.fetch = async (_url, options) => {
      const payload = JSON.parse(String(options?.body));
      assert.deepEqual(payload.messages.at(-1), { role: 'user', content: customer.message });
      assert.deepEqual(JSON.parse(payload.messages[1].content).context, customer.context);
      assert.equal(payload.response_format.json_schema.schema.properties.handoff.type, 'boolean');
      return Response.json({
        choices: [{ message: { content: JSON.stringify({
          reply: 'Vou encaminhar ao atendente humano.', summary: 'Cliente pediu humano.', handoff: true, create_lead: false, operator_request: '',
        }) } }], usage: { prompt_tokens: 100, completion_tokens: 20, total_tokens: 120 },
      });
    };
    const result = await engine.operate(customer) as any;
    assert.equal(result.handoff, true);
    assert.equal(result.create_lead, false);
  } finally {
    globalThis.fetch = original;
    await engine.close();
    await rm(dir, { recursive: true, force: true });
  }
});
