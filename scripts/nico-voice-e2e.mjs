import { readFile, writeFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const base = 'http://localhost:3000';
const env = await readFile(new URL('../local/nico.env', import.meta.url), 'utf8');
const password = env.match(/^NICO_LOCAL_PASSWORD=(.+)$/m)[1].trim();
const login = await fetch(base + '/auth/sign_in', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: 'admin@gopure.test', password }) });
assert.ok(login.ok);
const headers = {};
for (const key of ['access-token','client','uid','token-type']) if (login.headers.get(key)) headers[key] = login.headers.get(key);
const path = '/api/v1/accounts/1/jrc_nico/operations';
try {
  const before = await (await fetch(base + path, { headers })).json();
  const form = new FormData();
  form.append('audio', new Blob([await readFile(new URL('../services/nico-runtime/qa-voice.wav', import.meta.url))], { type: 'audio/wav' }), 'synthetic-test.wav');
  const response = await fetch(base + path + '/transcribe', { method: 'POST', headers, body: form, signal: AbortSignal.timeout(60000) });
  const data = await response.json();
  assert.equal(response.status, 200, data.error);
  assert.match(data.text, /contato.*teste/i);
  const after = await (await fetch(base + path, { headers })).json();
  assert.deepEqual(after.commands.map(c => c.id), before.commands.map(c => c.id));
  const report = { passed: true, at: new Date().toISOString(), input: 'Áudio sintético: Crie um contato de teste.', transcription: data.text, command_created: false, microphone_used: false };
  await writeFile(new URL('../docs/validation/nico-voice-e2e.json', import.meta.url), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
} finally { await fetch(base + '/auth/sign_out', { method: 'DELETE', headers }); }
