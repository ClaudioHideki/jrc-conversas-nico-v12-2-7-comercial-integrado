import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';

test('HTTP boundary requires service auth, bounds input and denies unmapped accounts', { timeout: 90000 }, async () => {
  const child = spawn(process.execPath, ['src/server.ts'], { env: { ...process.env,
    PORT: '3199', NICO_MODE: 'fixture', NICO_ALLOWED_ACCOUNTS: '1', LOG_LEVEL: 'error',
    NICO_SERVICE_TOKEN: 'test-token-minimum-thirty-two-characters', NICO_PGLITE_DATA_DIR: '/tmp/nico-http-test',
  }, stdio: 'pipe' });
  const url = 'http://127.0.0.1:3199';
  let output = '';
  child.stderr.on('data', chunk => { output += chunk.toString(); });
  try {
    let ready = false;
    for (let attempt = 0; attempt < 300; attempt++) {
      if (child.exitCode !== null) throw new Error(`Server exited: ${output}`);
      try { ready = (await fetch(`${url}/health`)).ok; } catch {}
      if (ready) break;
      await new Promise(resolve => setTimeout(resolve, 200));
    }
    assert.ok(ready, 'runtime must become ready');
    assert.equal((await fetch(`${url}/v1/analyze`, { method: 'POST' })).status, 401);
    const headers = { authorization: 'Bearer test-token-minimum-thirty-two-characters', 'content-type': 'application/json' };
    assert.equal((await fetch(`${url}/v1/analyze`, { method: 'POST', headers, body: '{' })).status, 422);
    const input = { request_id: 'a56905c4-9a03-4c21-a886-b5d18a3e4c57', account_id: 2, agent_key: 'nico', message: 'Resumo', history: [], context: { conversation: [], crm: [], knowledge: [] } };
    assert.equal((await fetch(`${url}/v1/analyze`, { method: 'POST', headers, body: JSON.stringify(input) })).status, 403);
    const response = await fetch(`${url}/v1/analyze`, { method: 'POST', headers, body: JSON.stringify({ ...input, account_id: 1 }) });
    assert.equal(response.status, 200);
    assert.equal((await response.json()).mode, 'fixture');
    assert.equal((await fetch(`${url}/v1/analyze`, { method: 'POST', headers, body: 'a'.repeat(262145) })).status, 413);
  } finally {
    if (child.exitCode === null) {
      child.kill('SIGTERM');
      await new Promise(resolve => child.once('exit', resolve));
    }
  }
});
