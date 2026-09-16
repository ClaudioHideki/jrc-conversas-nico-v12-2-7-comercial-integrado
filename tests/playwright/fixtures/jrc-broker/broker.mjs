// Uses compiled Broker code and real PostgreSQL/auth/TLS. Only the phone provider is synthetic.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import pg from '/app/node_modules/pg/lib/index.js';
import { runMigrations } from '/app/apps/api/dist/db/migrate.js';
import { runInAdminTransaction, createOrganization } from '/app/apps/api/dist/modules/organizations/repository.js';
import { withOrganizationTransaction } from '/app/apps/api/dist/db/tenant-transaction.js';
import { createChatwootService } from '/app/apps/api/dist/modules/integrations/chatwoot-service.js';
import { createChatwootControlAuth } from '/app/apps/api/dist/modules/integrations/chatwoot-control-auth.js';
import { createMessagingMembershipResolver } from '/app/apps/api/dist/modules/messaging/membership.js';
import { startServer } from '/app/apps/api/dist/server.js';
import { runMessagingWorker } from '/app/apps/api/dist/commands/messaging-worker.js';

if (process.env.NODE_ENV !== 'test' || process.env.CONTRACT_TEST_ONLY !== 'true') throw new Error('ISOLATED_TEST_REQUIRED');
const { Pool } = pg;
const database = 'jrc_contract_20260916';
const admin = new Pool({ connectionString: 'postgresql://postgres@broker-postgres:5432/postgres' });
if (!(await admin.query('SELECT 1 FROM pg_database WHERE datname=$1', [database])).rowCount)
  await admin.query(`CREATE DATABASE ${database}`);
await admin.end();
await runMigrations(`postgresql://postgres@broker-postgres:5432/${database}`);
const db = new Pool({ connectionString: `postgresql://postgres@broker-postgres:5432/${database}` });
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const authPool = new Pool({ connectionString: process.env.AUTH_DATABASE_URL });
const transact = (org, fn) => withOrganizationTransaction(pool, org, fn);
let fixture;
if (existsSync('/contract/broker-fixture.json')) fixture = JSON.parse(readFileSync('/contract/broker-fixture.json'));
else {
  const rails = JSON.parse(readFileSync('/contract/rails-fixture.json'));
  const { org, owner } = await runInAdminTransaction(db, async tx => {
    const org = (await createOrganization(tx, { name: 'Synthetic contract', slug: `contract-${randomUUID()}` })).id;
    const owner = (await tx.query("INSERT INTO users(email,password_hash) VALUES($1,'synthetic-unused') RETURNING id", [`${org}@example.test`])).rows[0].id;
    await tx.query("INSERT INTO memberships(organization_id,user_id,role) VALUES($1,$2,'OWNER')", [org, owner]);
    return { org, owner };
  });
  const chatwoot = createChatwootService({ publicOrigin: 'https://broker.example.test', encryptionKey: process.env.INTEGRATION_ENCRYPTION_KEY,
    externalDestinationsEnabled: true, transact, resolveIntegration: async () => org });
  await chatwoot.destinations.request(org, { baseUrl: 'https://chatwoot.example.test', mode: 'EXTERNAL' });
  await db.query("UPDATE chatwoot_destinations SET approval_status='APPROVED',approved_at=now() WHERE organization_id=$1", [org]);
  await chatwoot.bindAccount(org, { accountId: rails.accountId, token: rails.chatwootToken });
  const auth = createChatwootControlAuth({ enabled: true, transact, hmacSecret: process.env.API_KEY_HMAC_SECRET,
    resolveCurrentRole: createMessagingMembershipResolver(authPool) });
  const credential = await auth.issueCredential({ kind: 'JWT', organizationId: org, actorId: owner, role: 'OWNER' },
    { name: 'Synthetic Rails control', scopes: ['chatwoot:read', 'chatwoot:pair', 'chatwoot:disconnect', 'chatwoot:manage'] }, randomUUID());
  const providerId = (await transact(org, tx => tx.query("INSERT INTO provider_accounts(organization_id,provider,name) VALUES($1,'BAILEYS','Synthetic QR') RETURNING id", [org]))).rows[0].id;
  fixture = { organizationId: org, credential, providerId };
  writeFileSync('/contract/broker-fixture.json', JSON.stringify(fixture));
}
process.env.MESSAGING_WORKER_ORGANIZATIONS = fixture.organizationId;
await db.query('UPDATE organization_limits SET max_instances=100 WHERE organization_id=$1', [fixture.organizationId]);
const states = new Map();
const stats = { pairs: 0, creates: 0, sends: 0 };
createServer(async (req, res) => {
  if (req.headers.apikey !== process.env.EVOLUTION_API_KEY) { res.writeHead(401).end(); return; }
  const url = new URL(req.url, 'http://fixture');
  let body = ''; for await (const chunk of req) body += chunk;
  const input = body ? JSON.parse(body) : {};
  let result = {};
  if (url.pathname === '/instance/create') {
    states.set(input.instanceName, 'close'); stats.creates++;
    result = { instance: { instanceName: input.instanceName, status: 'close' } };
  } else if (url.pathname === '/instance/fetchInstances') {
    const name = url.searchParams.get('instanceName');
    result = states.has(name) ? [{ name, instanceName: name, connectionStatus: states.get(name), ownerJid: states.get(name) === 'open' ? '15555550100@s.whatsapp.net' : null }] : [];
  } else if (url.pathname.startsWith('/instance/connectionState/')) result = { instance: { state: states.get(url.pathname.split('/').at(-1)) ?? 'close' } };
  else if (url.pathname.startsWith('/instance/connect/')) { stats.pairs++; result = { pairingCode: 'TESTONLY' }; }
  else if (url.pathname.startsWith('/instance/logout/')) states.set(url.pathname.split('/').at(-1), 'close');
  else if (url.pathname.startsWith('/message/')) { stats.sends++; result = { key: { id: `synthetic-${randomUUID()}` } }; }
  else if (url.pathname === '/__fixture/connect') for (const name of states.keys()) states.set(name, 'open');
  else if (!url.pathname.startsWith('/webhook/') && !url.pathname.startsWith('/settings/')) { res.writeHead(404).end(); return; }
  writeFileSync('/contract/provider-stats.json', JSON.stringify(stats));
  res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(result));
}).listen(3101, '127.0.0.1');
// NODE_ENV=test intentionally omits runtime routes in Broker's unit-test factory.
// Use its normal development bootstrap, with the isolated database/env above.
await startServer({ ...process.env, NODE_ENV: 'development' });
let working = false;
setInterval(async () => {
  if (working) return;
  working = true;
  try { await runMessagingWorker(process.env, false); }
  catch (error) { console.error('Synthetic worker failed:', error.name); }
  finally { working = false; }
}, 1000);
console.log('Synthetic Broker contract server ready');
