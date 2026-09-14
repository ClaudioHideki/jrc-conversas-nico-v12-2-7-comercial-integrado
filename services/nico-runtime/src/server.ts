import { createServer } from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { errorResponse } from './errors.ts';
import { createEngine } from './engine.ts';
import { validateInput } from './contract.ts';
import { validateOperation } from './operations.ts';
import { validateAudio } from './transcription.ts';

const token = process.env.NICO_SERVICE_TOKEN;
if (!token || token.length < 32) throw new Error('NICO_SERVICE_TOKEN must have at least 32 characters');
const accounts = new Set((process.env.NICO_ALLOWED_ACCOUNTS || '').split(',').filter(id => /^[1-9][0-9]*$/.test(id)));
if (!accounts.size) throw new Error('NICO_ALLOWED_ACCOUNTS is required');
const mode = process.env.NICO_MODE;
if (mode !== 'fixture' && mode !== 'provider') throw new Error('NICO_MODE must be fixture or provider');
if (mode === 'provider' && accounts.size !== 1) throw new Error('Use one provider account per runtime deployment');
const engine = await createEngine({ mode, dataDir: process.env.NICO_PGLITE_DATA_DIR, postgresUrl: process.env.NICO_DATABASE_URL,
  apiKey: process.env.NICO_PROVIDER_API_KEY, model: process.env.NICO_MODEL, baseUrl: process.env.NICO_PROVIDER_BASE_URL });

const server = createServer(async (req, res) => {
  const cancellation = new AbortController();
  res.on('close', () => { if (!res.writableEnded) cancellation.abort(); });
  const send = (status: number, body: unknown) => { if (res.destroyed || res.writableEnded) return; res.writeHead(status, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(body)); };
  const reject = (status: number, code: string) => {
    console.error(JSON.stringify({ event: 'nico_request_failed', code }));
    return send(status, { error: code });
  };
  if (req.url === '/health' && req.method === 'GET') return send(200, { ready: true, mode, provider_verified: false });
  const received = Buffer.from(req.headers.authorization || '');
  const expected = Buffer.from(`Bearer ${token}`);
  if (received.length !== expected.length || !timingSafeEqual(received, expected)) return reject(401, 'unauthorized');
  if (!['/v1/analyze', '/v1/operate', '/v1/transcribe'].includes(req.url || '') || req.method !== 'POST') return send(404, { error: 'not_found' });
  if (!req.headers['content-type']?.startsWith('application/json')) return send(415, { error: 'json_required' });
  try {
    let size = 0;
    const chunks: Buffer[] = [];
    for await (const chunk of req) {
      size += chunk.length;
      if (size > (req.url === '/v1/transcribe' ? 5600000 : 262144)) return send(413, { error: 'body_too_large' });
      chunks.push(chunk);
    }
    let input;
    try { input = (req.url === '/v1/transcribe' ? validateAudio : req.url === '/v1/operate' ? validateOperation : validateInput)(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
    catch { return send(422, { error: 'invalid_input' }); }
    if (!accounts.has(String(input.account_id))) return reject(403, 'account_not_configured');
    const result = req.url === '/v1/transcribe' ? await engine.transcribe(JSON.parse(Buffer.concat(chunks).toString('utf8')), cancellation.signal)
      : req.url === '/v1/operate' ? await engine.operate(input as any, cancellation.signal) : await engine.analyze(input as any, cancellation.signal);
    send(200, { ...result, request_id: input.request_id, account_id: input.account_id });
  } catch (error) {
    const failure = errorResponse(error, req.url || '');
    console.error(JSON.stringify(failure.log));
    send(failure.status, failure.body);
  }
});
server.requestTimeout = 10000;
server.headersTimeout = 10000;
server.listen(Number(process.env.PORT || 3108), '0.0.0.0');
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => { void engine.close().finally(() => process.exit(0)); }));
