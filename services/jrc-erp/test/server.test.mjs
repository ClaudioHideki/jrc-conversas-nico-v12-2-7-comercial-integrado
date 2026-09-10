import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';
test('gateway exige autenticação, tenant permitido e modo autorizado', async () => {
  const port = 35000 + process.pid % 20000;
  const token = 'only-test-service-token-01234567890123456789';
  const child = spawn(process.execPath, [fileURLToPath(new URL('../src/server.mjs', import.meta.url))], { env: { ...process.env, NICO_SERVICE_TOKEN: token, ERP_ALLOWED_ACCOUNTS: '1', ERP_LIVE_READ_ENABLED: 'false', PORT: String(port) }, stdio: 'ignore' });
  const base = `http://127.0.0.1:${port}`;
  try {
    let ready = false;
    for (let i=0;i<60;i++) { try { if ((await fetch(`${base}/health`)).ok) { ready=true;break; } } catch {} await delay(50); }
    assert.ok(ready, 'gateway did not start');
    const call = (body, auth=token) => fetch(`${base}/context`, { method:'POST', headers:{'Content-Type':'application/json', Authorization:`Bearer ${auth}`},body:JSON.stringify(body) });
    assert.equal((await call({account_id:1,mode:'fixture',agent_key:'nico'}, 'bad')).status,401);
    assert.equal((await call({account_id:2,mode:'fixture',agent_key:'nico'})).status,403);
    assert.equal((await call({account_id:1,mode:'live',agent_key:'nico'})).status,403);
    const response=await call({account_id:1,mode:'fixture',agent_key:'nico'});
    assert.equal(response.status,200);
    const body=await response.json();assert.equal(body.mode,'fixture');assert.ok(body.items[0].text.includes('SIMULAÇÃO'));
  } finally { const stopped=once(child,'exit');child.kill();await stopped; }
});
