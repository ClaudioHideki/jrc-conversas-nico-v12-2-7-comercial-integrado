import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createEngine } from '../src/engine.ts';

test('real elizaOS initializes SQL and dispatches the explicit fixture model', async () => {
  const engine = await createEngine({ mode: 'fixture', dataDir: '/tmp/nico-runtime-test' });
  try {
    const result = await engine.analyze({
      request_id: 'a56905c4-9a03-4c21-a886-b5d18a3e4c57', account_id: 1,
      agent_key: 'nico', message: 'Resuma', history: [],
      context: { conversation: [{ source: 'conversation', reference: 'message:10', text: 'Olá' }], crm: [], knowledge: [] },
    });
    assert.equal(result.mode, 'fixture');
    assert.equal(result.model, 'fixture-local');
    assert.ok(result.warnings.some(warning => warning.includes('sem provedor de IA')));
    assert.deepEqual(result.evidence, [{ source: 'conversation', reference: 'message:10' }]);
    assert.equal(result.usage, null);
    assert.equal(engine.runtime.character.name, 'NICO');
    assert.equal(engine.runtime.actions.length, 0);
  } finally { await engine.close(); }
});
