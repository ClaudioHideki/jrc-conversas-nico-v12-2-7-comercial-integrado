import { agents, type AgentKey } from './agents.ts';
export type Evidence = { source: string; reference: string };
export type ContextItem = Evidence & { text: string };
export type Context = { conversation: ContextItem[]; crm: ContextItem[]; knowledge: ContextItem[]; erp?: ContextItem[] };
export type Input = { request_id: string; account_id: number; agent_key: AgentKey; message: string; history: { role: string; content: string }[]; context: Context };
export type Analysis = { summary: string; suggested_reply: string; evidence: Evidence[]; warnings: string[] };

function object(value: unknown, keys: string[]): asserts value is Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid object');
  if (Object.keys(value).some(key => !keys.includes(key)) || keys.some(key => !(key in value))) throw new Error('Invalid fields');
}
function string(value: unknown, max: number, min = 0): asserts value is string {
  if (typeof value !== 'string' || value.length < min || value.length > max) throw new Error('Invalid text');
}
function array(value: unknown, max: number): asserts value is unknown[] {
  if (!Array.isArray(value) || value.length > max) throw new Error('Invalid array');
}
export function validateInput(value: unknown): Input {
  object(value, ['request_id', 'account_id', 'agent_key', 'message', 'history', 'context']);
  string(value.request_id, 36, 36);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value.request_id)) throw new Error('Invalid request id');
  if (!Number.isSafeInteger(value.account_id) || Number(value.account_id) < 1 || typeof value.agent_key !== 'string' || !Object.hasOwn(agents, value.agent_key)) throw new Error('Invalid scope');
  string(value.message, 4000, 1);
  array(value.history, 8);
  value.history.forEach(item => {
    object(item, ['role', 'content']);
    string(item.role, 10, 1);
    if (!['user', 'assistant'].includes(String(item.role))) throw new Error('Invalid role');
    string(item.content, 4000);
  });
  const sources = ['conversation', 'crm', 'knowledge'];
  if (value.context && typeof value.context === 'object' && 'erp' in value.context) sources.push('erp');
  object(value.context, sources);
  for (const source of sources) {
    const items = value.context[source];
    array(items, source === 'conversation' ? 40 : 10);
    items.forEach(item => {
      object(item, ['source', 'reference', 'text']);
      if (item.source !== source) throw new Error('Invalid source');
      string(item.reference, 150, 1);
      string(item.text, 4000);
    });
  }
  return value as unknown as Input;
}
export function validateAnalysis(value: unknown, context: Context): Analysis {
  object(value, ['summary', 'suggested_reply', 'evidence', 'warnings']);
  string(value.summary, 8000, 1);
  string(value.suggested_reply, 4000);
  array(value.evidence, 30);
  const allowed = new Set(Object.values(context).flat().map(item => `${item.source}:${item.reference}`));
  value.evidence.forEach(item => {
    object(item, ['source', 'reference']);
    string(item.source, 20, 1);
    string(item.reference, 150, 1);
    if (!allowed.has(`${item.source}:${item.reference}`)) throw new Error('Unsupported evidence');
  });
  array(value.warnings, 10);
  value.warnings.forEach(item => string(item, 1000));
  return value as unknown as Analysis;
}
