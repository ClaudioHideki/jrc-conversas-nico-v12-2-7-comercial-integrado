import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluate } from './evaluate.mjs';

test('code receives input and prior node results', async () => {
  const result = await evaluate({ code: 'return [{json:{result:$json.n + $("Anterior").first().json.n}}];', input: [{ json: { n: 2 } }], outputs: { Anterior: [{ json: { n: 5 } }] } });
  assert.equal(result[0].json.result, 7);
});
test('expressions preserve object and numeric values', async () => {
  const result = await evaluate({ input: [{ json: { n: 7 } }], parameters: { n: '={{ $json.n }}', body: '={{ { ok: true } }}', key: '=turn:{{ $json.n }}' } });
  assert.deepEqual(result, { n: 7, body: { ok: true }, key: 'turn:7' });
});
test('guest cannot access host globals even through Function', async () => {
  const result = await evaluate({ code: 'return [typeof process, typeof require, typeof fetch, Function("return typeof process")()];', input: [] });
  assert.deepEqual(result, ['undefined', 'undefined', 'undefined', 'undefined']);
});
test('loop is interrupted and next evaluation remains usable', async () => {
  await assert.rejects(evaluate({ code: 'while(true){}', input: [] }), /interrupted/);
  assert.equal(await evaluate({ code: 'return 42;', input: [] }), 42);
});
test('async and invalid result cannot silently run', async () => {
  await assert.rejects(evaluate({ code: 'return Promise.resolve(1);', input: [] }), /síncrono/);
});
