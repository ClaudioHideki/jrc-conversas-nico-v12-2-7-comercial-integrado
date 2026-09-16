// Local contract harness only. Never include this server in a production image.
import https from 'node:https';
import http from 'node:http';
import { readFileSync, existsSync, unlinkSync, writeFileSync } from 'node:fs';
import pg from '/app/node_modules/pg/lib/index.js';

if (process.env.CONTRACT_TEST_ONLY !== 'true') throw new Error('ISOLATED_TEST_REQUIRED');
const railsDb = new pg.Pool({ host: 'contract-rails-postgres', user: 'postgres', database: 'jrc_broker_native_test', max: 1 });
const brokerDb = new pg.Pool({ host: 'broker-postgres', user: 'postgres', database: 'jrc_contract_20260916', max: 1 });
const stats = { brokerRequests: 0, callbacks: 0, rejectedBeforeAck: 0, inboxPosts: 0, maxIdleTransactions: 0 };
const save = () => writeFileSync('/contract/gateway-stats.json', JSON.stringify(stats));
https.createServer({ key: readFileSync('/contract/tls.key'), cert: readFileSync('/contract/tls.crt') }, async (req, res) => {
  const host = req.headers.host?.split(':')[0];
  if (!['broker.example.test', 'chatwoot.example.test', 'localhost'].includes(host)) {
    res.writeHead(421).end(); return;
  }
  const broker = host === 'broker.example.test';
  if (req.url === '/__contract/evidence' && req.method === 'GET') {
    res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(stats)); return;
  }
  if (!broker && req.method === 'POST' && /^\/api\/v1\/accounts\/\d+\/inboxes$/.test(req.url)) {
    stats.inboxPosts++;
    try {
      for (const db of [railsDb, brokerDb]) {
        // Hold the HTTP request before forwarding. A caller retaining a transaction
        // across HTTP remains in both snapshots; a short worker claim does not.
        const sample = () => db.query("SELECT pid,xact_start::text FROM pg_stat_activity WHERE datname=current_database() AND state='idle in transaction'");
        const before = (await sample()).rows;
        await new Promise(resolve => setTimeout(resolve, 150));
        const after = (await sample()).rows;
        const held = after.filter(row => before.some(old => old.pid === row.pid && old.xact_start === row.xact_start));
        stats.maxIdleTransactions = Math.max(stats.maxIdleTransactions, held.length);
      }
    } catch { res.writeHead(503).end(); return; }
  }
  if (broker) stats.brokerRequests++;
  if (broker && /^\/v1\/integrations\/chatwoot\/[^/]+\/events$/.test(req.url)) {
    stats.callbacks++;
    if (existsSync('/contract/reject-next-callback')) {
      unlinkSync('/contract/reject-next-callback'); stats.rejectedBeforeAck++; save();
      res.writeHead(503).end(); return;
    }
  }
  save();
  const upstream = http.request({ host: broker ? 'broker-contract-api' : 'jrc-native-validation-runtime-20260916', port: 3000,
    path: req.url, method: req.method, headers: { ...req.headers, 'x-forwarded-proto': 'https' } }, reply => {
    res.writeHead(reply.statusCode, reply.headers); reply.pipe(res);
  });
  upstream.on('error', () => { if (!res.headersSent) res.writeHead(503); res.end(); });
  req.pipe(upstream);
}).listen(443, '0.0.0.0', () => console.log('Synthetic contract TLS gateway ready'));
