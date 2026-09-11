import { AgentRuntime, ModelType, stringToUuid, createLogger, logger, type Plugin } from '@elizaos/core';
import sqlPlugin, { createDatabaseAdapter } from '@elizaos/plugin-sql';
import { validateAnalysis, validateInput, type Input, type Analysis } from './contract.ts';
import { agentPrompt } from './agents.ts';
import { analysisSchema } from './schema.ts';
import { AsyncLocalStorage } from 'node:async_hooks';
import { transcribeAudio } from './transcription.ts';
import { validateOperation, validateOperationResult, operationPrompt, operationSchema, customerSchema, type OperationInput } from './operations.ts';

type Usage = { input_tokens: number; output_tokens: number; total_tokens: number };
export type Result = Analysis & { usage: Usage | null; model: string; mode: string };
type Config = { mode: 'fixture' | 'provider'; dataDir?: string; postgresUrl?: string; model?: string; apiKey?: string; baseUrl?: string };

async function readJson(response: Response): Promise<any> {
  if (!response.ok || !response.body) throw new Error(`Provider request failed HTTP ${response.status}`);
  const reader = response.body.getReader();
  const parts: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 131072) throw new Error('Provider response too large');
      parts.push(value);
    }
    const text = Buffer.concat(parts).toString('utf8');
    try {
      return JSON.parse(text);
    } catch {
      const preview = text.replace(/\s+/g, ' ').slice(0, 300);
      throw new Error(`Provider response invalid JSON: ${preview || '<empty>'}`);
    }
  } finally { await reader.cancel(); }
}

export async function createEngine(config: Config) {
  // core useModel traces whole prompts. This dedicated service never emits SDK logs,
  // even when an operator sets LOG_LEVEL=trace. Rails owns redacted operational logs.
  const quiet = createLogger({ level: 'error' });
  for (const level of ['trace', 'debug', 'info', 'warn', 'error', 'fatal', 'success', 'log'] as const) {
    Object.assign(quiet, { [level]: () => {} });
  }
  quiet.child = () => quiet;
  Object.assign(logger, quiet);
  if (!['fixture', 'provider'].includes(config.mode)) throw new Error('Invalid mode');
  if (config.mode === 'provider' && (!config.apiKey || !config.model)) throw new Error('Provider configuration missing');
  const baseUrl = new URL(config.baseUrl || 'https://api.openai.com/v1/');
  if (config.mode === 'provider' && baseUrl.protocol !== 'https:') throw new Error('Provider requires HTTPS');
  const id = stringToUuid('jrc:nico:assisted:v1');
  const adapter = createDatabaseAdapter({ dataDir: config.dataDir, postgresUrl: config.postgresUrl }, id);
  await adapter.init();
  await adapter.runPluginMigrations([{ name: sqlPlugin.name, schema: sqlPlugin.schema }], { force: false });
  // Authorized prompts/results belong to Rails audit, never generic model memory.
  adapter.log = async () => {};
  const signals = new AsyncLocalStorage<AbortSignal | undefined>();
  const model: Plugin = {
    name: 'nico-bounded-analysis', description: 'Read-only structured analysis with bounded transport',
    models: {
      [ModelType.OBJECT_LARGE]: async (_runtime, params: { prompt: string }) => {
        const raw = JSON.parse(params.prompt);
        const operational = 'kind' in raw;
        const input = operational ? validateOperation(raw) : validateInput(raw);
        if (config.mode === 'fixture') {
          if (operational) return { ...(raw.kind === 'customer'
            ? { reply: '', summary: 'Simulação sem envio ao cliente.', handoff: true, create_lead: false, operator_request: '' }
            : { reply: 'Simulação local. Configure o provedor para interpretar pedidos.', tool: '', arguments: '{}' }),
            usage: null, model: 'fixture-local', mode: 'fixture' };
          const items = Object.values((input as Input).context).flat();
          return {
            summary: `Homologação local: ${items.length} referências autorizadas recebidas.`,
            suggested_reply: '', evidence: items.slice(0, 10).map(({ source, reference }) => ({ source, reference })),
            warnings: ['Simulação local sem provedor de IA. Este resultado valida a integração e não é uma análise de IA.'],
            usage: null, model: 'fixture-local', mode: 'fixture',
          };
        }
        const response = await fetch(`${baseUrl.href.replace(/\/$/, '')}/chat/completions`, {
          method: 'POST', signal: AbortSignal.any([AbortSignal.timeout(45000), ...(signals.getStore() ? [signals.getStore()!] : [])]), redirect: 'error',
          headers: { Authorization: `Bearer ${config.apiKey}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ model: config.model, temperature: 0, max_completion_tokens: 2000,
            response_format: { type: 'json_schema', json_schema: {
              name: 'nico_assisted_analysis', strict: true,
              schema: operational ? (raw.kind === 'customer' ? customerSchema : operationSchema) : analysisSchema,
            } },
            messages: [
              { role: 'system', content: operational ? operationPrompt(raw.kind) : agentPrompt((input as Input).agent_key) },
              { role: 'user', content: JSON.stringify(input) },
              // Keep the current customer turn after the historical context, so an
              // earlier question or the qualification objective cannot become the turn to answer.
              ...(operational && raw.kind === 'customer'
                ? [{ role: 'user', content: (input as OperationInput).message }] : []),
            ],
          }),
        });
        const body = await readJson(response);
        let parsed;
        try { parsed = JSON.parse(body.choices?.[0]?.message?.content); }
        catch { throw new Error('Provider output not JSON'); }
        const analysis = operational ? validateOperationResult(parsed, raw.kind) : validateAnalysis(parsed, (input as Input).context);
        const usage = body.usage;
        if (!usage || ![usage.prompt_tokens, usage.completion_tokens, usage.total_tokens].every(n => Number.isSafeInteger(n) && n >= 0 && n <= 270000)
          || usage.prompt_tokens + usage.completion_tokens !== usage.total_tokens) {
          throw new Error('Provider usage unavailable');
        }
        return { ...analysis, usage: { input_tokens: usage.prompt_tokens, output_tokens: usage.completion_tokens, total_tokens: usage.total_tokens }, model: config.model, mode: 'provider' };
      },
    },
  };
  const runtime = new AgentRuntime({ character: { id, name: 'NICO', bio: ['Copiloto assistido do JRC'] }, adapter, plugins: [model] });
  runtime.logger = quiet;
  await runtime.initialize({ skipMigrations: true });
  let active = 0;
  const concurrency = Math.max(1, Math.min(8, Number(process.env.NICO_MAX_CONCURRENCY || 3)));
  async function invoke(input: Input | OperationInput, signal?: AbortSignal) {
    if (active >= concurrency) throw new Error('Runtime busy');
    active += 1;
    try {
      signal?.throwIfAborted();
      return await signals.run(signal, () => runtime.useModel(ModelType.OBJECT_LARGE, { prompt: JSON.stringify(input), temperature: 0 }));
    } finally { active -= 1; }
  }
  return {
    runtime,
    async analyze(input: Input, signal?: AbortSignal): Promise<Result> {
      validateInput(input);
        const result = await invoke(input, signal) as Result;
        const { usage, model: modelName, mode, ...analysis } = result;
        validateAnalysis(analysis, input.context);
        return { ...analysis, usage, model: modelName, mode };
    },
    async operate(input: OperationInput, signal?: AbortSignal) {
      validateOperation(input);
      return await invoke(input, signal);
    },
    async transcribe(input: unknown, signal?: AbortSignal) {
      if (active >= concurrency) throw new Error('Runtime busy');
      active += 1;
      try { return await transcribeAudio(input, config, signal); }
      finally { active -= 1; }
    },
    async close() { await runtime.stop(); await runtime.close(); },
  };
}

