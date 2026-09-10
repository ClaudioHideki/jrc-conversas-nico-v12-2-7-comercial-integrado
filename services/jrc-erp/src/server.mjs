import http from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { ErpClient, ErpError } from './client.mjs';
import { transport } from './transport.mjs';
import { fixtureBinding, fixtureContext } from './fixture.mjs';
const token = process.env.NICO_SERVICE_TOKEN;
if (!token || token.length < 32) throw new Error('Service token required');
const allowed = (process.env.ERP_ALLOWED_ACCOUNTS || '').split(',');
const client = new ErpClient(process.env, transport);
const equal = value => { const a = Buffer.from(value || ''); const b = Buffer.from(`Bearer ${token}`); return a.length === b.length && timingSafeEqual(a, b); };
http.createServer(async (req, res) => {
  const send = (status, data) => { res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(data)); };
  if (req.method === 'GET' && req.url === '/health') return send(200, { status: 'ok' });
  if (!equal(req.headers.authorization)) return send(401, { error: 'unauthorized' });
  if (req.method !== 'POST' || !['/resolve', '/context'].includes(req.url)) return send(404, { error: 'not_found' });
  try {
    let raw = ''; for await (const chunk of req) { raw += chunk; if (Buffer.byteLength(raw) > 4096) throw new ErpError('input_too_large'); }
    const input = JSON.parse(raw);
    if (!allowed.includes(String(input.account_id))) return send(403, { error: 'account_denied' });
    if (!['fixture', 'live'].includes(input.mode)) throw new ErpError('mode_denied');
    if (input.mode === 'live' && process.env.ERP_LIVE_READ_ENABLED !== 'true') return send(403, { error: 'live_disabled' });
    if (req.url === '/resolve') return send(200, input.mode === 'fixture' ? fixtureBinding : await client.resolve(input.cnpj));
    if (!['nico', 'comercial', 'cx', 'suporte_n1', 'financeiro', 'implantacao', 'supervisor'].includes(input.agent_key)) throw new ErpError('agent_denied');
    return send(200, { items: input.mode === 'fixture' ? fixtureContext() : await client.context(input.binding, input.agent_key), mode: input.mode });
  } catch (error) { return send(422, { error: error instanceof ErpError ? error.message : 'erp_unavailable' }); }
}).listen(Number(process.env.PORT || 3112), '0.0.0.0');
