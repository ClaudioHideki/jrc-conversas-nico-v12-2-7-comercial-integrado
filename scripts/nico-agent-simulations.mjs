import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { agents, agentPrompt } from '../services/nico-runtime/src/agents.ts';
import { validateInput, validateAnalysis } from '../services/nico-runtime/src/contract.ts';
import { fixtureContext } from '../services/jrc-erp/src/fixture.mjs';
import { analysisSchema } from '../services/nico-runtime/src/schema.ts';
const mode = process.argv.includes('--provider') ? 'provider' : 'fixture';
const env = { ...process.env };
if (mode === 'provider' && !env.NICO_PROVIDER_API_KEY) {
  for (const line of (await readFile(new URL('../local/nico-provider.env', import.meta.url), 'utf8')).split(/\r?\n/)) {
    const match = line.match(/^([A-Z_]+)=(.*)$/); if (match) env[match[1]] = match[2];
  }
}
const cases = {
  nico: 'Olá, quero aumentar meus ramais e preciso de ajuda com uma falha de áudio.',
  comercial: 'Temos cinco ramais e queremos dez. Pode levantar o que falta para uma proposta?',
  cx: 'Estou insatisfeito porque o problema de áudio ainda não foi resolvido.',
  suporte_n1: 'Um ramal fica sem áudio em um dos sentidos. Já existe um chamado?',
  financeiro: 'Pode me mandar a segunda via e confirmar se o pagamento foi recebido?',
  implantacao: 'O que precisamos organizar para ampliar os ramais e treinar a equipe?',
  supervisor: 'Revise as pendências desta conversa e indique quando chamar um atendente humano.',
};
const reports = [];
for (const [key, message] of Object.entries(cases)) {
  const context = {
    conversation: [{ source: 'conversation', reference: 'message:synthetic', text: `SIMULAÇÃO com cliente fictício: ${message}` }],
    crm: [{ source: 'crm', reference: 'lead:synthetic', text: 'Lead fictício, expansão de cinco para dez ramais. Prazo, decisor e orçamento ainda não informados.' }],
    knowledge: [{ source: 'knowledge', reference: 'document:synthetic', text: 'Procedimento fictício de triagem: perguntar ramal afetado, horário, origem/destino e se a falha ocorre em todas as ligações. Não solicitar senhas. Encaminhar diagnóstico remoto à equipe humana.' }],
    erp: fixtureContext().map(item => ({ source: 'erp', reference: `binding:synthetic:${item.kind}`, text: item.text })),
  };
  const input = validateInput({ request_id: randomUUID(), account_id: 1, agent_key: key, message, history: [], context });
  let analysis; let usage = null;
  if (mode === 'provider') {
    if (!env.NICO_PROVIDER_API_KEY || !env.NICO_MODEL) throw new Error('Provider configuration required');
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(60000),
      headers: { Authorization: `Bearer ${env.NICO_PROVIDER_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: env.NICO_MODEL, temperature: 0, max_completion_tokens: 1600,
        response_format: { type: 'json_schema', json_schema: { name: 'nico_assisted_analysis', strict: true, schema: analysisSchema } }, messages: [{ role: 'system', content: agentPrompt(key) }, { role: 'user', content: JSON.stringify(input) }] }),
    });
    if (!response.ok) throw new Error(`Provider HTTP ${response.status}`);
    const body = await response.json();
    analysis = validateAnalysis(JSON.parse(body.choices[0].message.content), context);
    usage = body.usage;
    if (!analysis.suggested_reply || !analysis.evidence.length || !/simula|fict[ií]ci/i.test(JSON.stringify(analysis))) throw new Error(`Missing simulation disclosure/evidence/reply: ${key}`);
  } else {
    analysis = validateAnalysis({ summary: 'Simulação de contrato sem modelo de IA.', suggested_reply: '', evidence: context.erp.map(({source,reference}) => ({source,reference})), warnings: ['Fixture: não demonstra raciocínio de IA.'] }, context);
  }
  reports.push({ agent: key, name: agents[key].name, message, passed: true, analysis, usage });
  console.log(`${key}: contract passed (${mode})`);
}
const dir = new URL('../docs/validation/', import.meta.url);
await mkdir(dir, { recursive: true });
const report = { at: new Date().toISOString(), mode, model: mode === 'provider' ? env.NICO_MODEL : null,
  scope: 'Agent prompts + synthetic ERP context + output contract. Not Rails/UI/eliza-runtime end-to-end.', external_business_writes: false, reports };
await writeFile(new URL(`gopure-agent-simulations-${mode}.json`, dir), JSON.stringify(report, null, 2));
await writeFile(new URL(`gopure-agent-simulations-${mode}.md`, dir), `# Simulações GoPure — ${mode}\n\nDados fictícios. Teste de prompts e contrato; não comprova execução ponta a ponta no Rails/elizaOS.\n\n` + reports.map(r => `## ${r.name}\n\n**Cliente fictício:** ${r.message}\n\n**Análise:** ${r.analysis.summary}\n\n**Resposta sugerida:** ${r.analysis.suggested_reply}\n\n**Limitações:** ${r.analysis.warnings.join(' ')}\n`).join('\n'));
