# elizaOS published runtime research — 2026-09-07

Read-only investigation of public npm manifests and the exact published tarballs; no dependencies installed, credentials used, or product files changed. This report supports `2026-09-07-nico-design.md`. Source inspection is not an executed integration test.

## Version decision

| Package | Exact pin | Published compatibility evidence |
| --- | --- | --- |
| `@elizaos/core` | `1.7.2` | npm `latest` returned this stable release |
| `@elizaos/plugin-sql` | `1.7.2` | depends on core **exactly** `1.7.2` |
| `@elizaos/plugin-openai` | `1.6.0` | depends on core `^1.7.0`, AI SDK `^5.0.47`, OpenAI SDK adapter `^2.0.32`; peer Zod `^3.25.76 || ^4.1.8` |

Use an exact lockfile as well as direct pins. Core depends on Zod `^4.3.5`; SQL on Drizzle `^0.45.0`, PGlite `^0.3.3` and pg `^8.13.3`. Do not select GitHub main as a release: the inspected main manifest is already `2.0.3-beta.7` with substantially different dependencies. The three npm manifests expose no `engines` requirement. Node 24 ESM is the recommended deployment baseline; the bundled executable reports `v24.19.0`. Dependency installation and runtime import must still be verified against the chosen lockfile.

Primary sources: [core manifest](https://registry.npmjs.org/@elizaos/core/1.7.2), [SQL manifest](https://registry.npmjs.org/@elizaos/plugin-sql/1.7.2), [OpenAI manifest](https://registry.npmjs.org/@elizaos/plugin-openai/1.6.0). Exact examined bundles: [core tarball](https://registry.npmjs.org/@elizaos/core/-/core-1.7.2.tgz), [SQL tarball](https://registry.npmjs.org/@elizaos/plugin-sql/-/plugin-sql-1.7.2.tgz), [OpenAI tarball](https://registry.npmjs.org/@elizaos/plugin-openai/-/plugin-openai-1.6.0.tgz). [Official runtime documentation](https://docs.elizaos.ai/runtime/core) supplies architectural context, but the published implementation is authoritative for this version.

## Verified API and material traps

1. `new AgentRuntime({ character, adapter, plugins, settings })`, `await runtime.initialize({ skipMigrations: true })`, and `runtime.useModel(ModelType.OBJECT_LARGE, { prompt, temperature: 0 })` are real published APIs. No bootstrap plugin, autonomous message pipeline, providers or actions are required for this restricted analysis operation.
2. `initialize()` requires a database adapter. It calls `ensureAgentExists` **before** plugin migrations. SQL `adapter.init()` merely logs initialization. On a new database, explicitly call `adapter.runPluginMigrations([{name: sqlPlugin.name, schema: sqlPlugin.schema}], {force:false})` first. Then initialize runtime with migrations skipped. Run one migrator per deployment, not concurrent migrations for every request.
3. `plugin-openai`'s OBJECT handler accepts but **ignores** `schema`, uses AI SDK `generateObject({output: 'no-schema'})`, and returns the object only. Application-level strict validation is mandatory. It only forwards prompt and temperature; system text must be included deliberately in the prompt. Max tokens and abort signal supplied to this stock handler are not forwarded.
4. The full OpenAI plugin starts an unawaited `GET /models` during init and registers embeddings; runtime initialization probes the embedding model. For a request-only deployment, register a narrow local plugin containing the official OBJECT handler alone. This still uses actual elizaOS runtime dispatch and the actual published model handler. Do not spread the entire official plugin, which would restore init/tests/other handlers.
5. `useModel` calls `adapter.log` with full prompt, parameters and response. The runtime also traces model input. Disable trace/debug, sanitize or suppress this database log path, and retain request metadata/audit in Rails. Do not assume prompts stay transient. Runtime settings should contain deployment secrets; do not put keys in persisted character metadata.
6. `EventType.MODEL_USED` carries `{tokens:{prompt,completion,total},source:'openai',provider:'openai',type,prompt}`; its prompt contains up to 200 characters. Capture only token counters. The handler returns no usage object. Async-local request context or per-runtime serialization is needed; adding listeners per concurrent request will misattribute usage. Never invent zero usage when no event was obtained.
7. Runtime has mutable `currentRunId/currentRoomId`; serialize calls within a runtime or avoid mutable run helpers and use request-scoped correlation. Never obtain cross-account context from its SQL memory: Rails is the only authorized source.
8. SQL 1.7.2 has a packaging defect: exports points to `types/index.d.ts`, absent in the examined tarball; `dist/node/index.d.ts` re-exports `./index.node`, whose declaration is also absent. Runtime JS exists. A narrow local declaration shim for the actually used SQL API may be needed; do not disable type checking globally.

Exact bundle evidence locations: core `dist/node/index.node.js` constructor/initialize around lines 48920/49074, model dispatch around 50218, model database logging around 50185, close around 50438; SQL adapter factory and plugin around 21105/21159, migrations around 14691; OpenAI initialization around 72, usage around 117, object handler around 569 and plugin models around 656.

## Minimal real API skeleton

This is a source-verified skeleton, not a tested complete HTTP server. The application supplies `validateAnalysis` and evidence allowlist checking. Keys below are deployment environment values, never request parameters.

```ts
import { AgentRuntime, ModelType, stringToUuid, type Plugin } from '@elizaos/core';
import sqlPlugin, { createDatabaseAdapter } from '@elizaos/plugin-sql';
import { openaiPlugin } from '@elizaos/plugin-openai';

const agentId = stringToUuid('nico:approved-analysis:v1');
const adapter = createDatabaseAdapter({
  postgresUrl: process.env.NICO_DATABASE_URL,
  dataDir: process.env.NICO_PGLITE_DATA_DIR,
}, agentId);
await adapter.init();
await adapter.runPluginMigrations([
  { name: sqlPlugin.name, schema: sqlPlugin.schema },
], { force: false });

// Rails persists audit and result; prevent elizaOS copying authorized content
// into its own generic model logs. Other adapter operations remain real SQL.
adapter.log = async () => {};

const objectHandler = openaiPlugin.models?.[ModelType.OBJECT_LARGE];
if (!objectHandler) throw new Error('Pinned OpenAI OBJECT_LARGE handler missing');
const modelPlugin: Plugin = {
  name: 'nico-approved-openai-object',
  description: 'Only the published OpenAI object handler; no actions or services',
  models: { [ModelType.OBJECT_LARGE]: objectHandler },
};
const runtime = new AgentRuntime({
  character: { id: agentId, name: 'NICO', bio: ['Copiloto assistido do JRC'] },
  adapter,
  plugins: [modelPlugin],
  settings: {
    OPENAI_API_KEY: process.env.OPENAI_API_KEY!,
    OPENAI_LARGE_MODEL: process.env.NICO_MODEL!,
    OPENAI_BASE_URL: process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
  },
});
await runtime.initialize({ skipMigrations: true });

async function analyze(promptBuiltOnlyFromAuthorizedRailsInput: string) {
  const raw = await runtime.useModel(ModelType.OBJECT_LARGE, {
    prompt: promptBuiltOnlyFromAuthorizedRailsInput,
    temperature: 0,
  });
  return validateAnalysis(raw); // strict keys/types/limits + evidence membership
}

async function shutdown() {
  await runtime.stop(); // stops services, does not close adapter
  await runtime.close();
}
```

Production transport requires more work than the skeleton: the stock object handler cannot enforce hard cancellation/output limits. Either enforce a bounded provider gateway or create a constrained local elizaOS model plugin that forwards `AbortSignal`, output cap and exact usage to an SDK/provider transport. The latter remains real elizaOS when the initialized AgentRuntime registers and dispatches it; test dispatch through the real core rather than replacing AgentRuntime with a mock. Do not label a raw HTTP call that bypasses runtime as elizaOS integration.

## Storage and deployment boundaries

Use a separate runtime database/role or local PGlite volume, never Rails' schema. Migrations create SQL extension/schema objects; verify required permissions with the chosen PostgreSQL/pgvector image. The PGlite adapter includes vector and fuzzystrmatch extensions and is useful for isolated local tests. A single PGlite manager is global in the package; multiple data directories in one process do not provide independent databases. PostgreSQL factory pooling is also global and keyed by isolation server ID/driver, not by connection URL; do not use varying tenant connection strings with this factory in one process. Keep one deployment DSN and authorized-context-only processing for this scope.

Declare readiness only after adapter/migrations/runtime initialize. Missing key/model/token must fail closed. Health must not claim provider validity without a successful controlled request. Keep runtime private and validate the service bearer token before JSON parsing/work. Bound request size, queue/concurrency, timeouts and response length. `POST /v1/analyze` accepts only the design contract; unknown agent keys and account mappings fail closed. Evidence must match source/reference pairs actually supplied in authorized context, rather than trusting model citations. Output validation must exclude arbitrary extra fields and normalize only with explicit semantics.

No autonomous actions, public channel plugins, web tools, knowledge retrieval from shared runtime state, or customer delivery are needed. A controlled provider test must exercise actual runtime initialization, SQL migrations, model registration/dispatch, strict output errors, timeouts and tenant isolation. Live provider readiness remains a separate deployment acceptance step with authorized credentials.
