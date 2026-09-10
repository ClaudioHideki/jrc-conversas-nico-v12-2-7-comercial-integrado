import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateInput, validateAnalysis } from '../src/contract.ts';
const input = { request_id: 'b20c7b1c-8270-4ec7-a8b5-dbf11aefc217', account_id: 1, agent_key: 'nico', message: 'Analisar', history: [], context: { conversation: [], crm: [], knowledge: [], erp: [{ source: 'erp', reference: 'binding:1:abcdef', text: 'SIMULAÇÃO' }] } };
test('aceita fonte ERP explicitamente autorizada', () => { assert.equal(validateInput(input).context.erp?.length, 1); });
test('não aceita referência ERP inventada', () => { assert.throws(() => validateAnalysis({ summary: 'Análise', suggested_reply: '', evidence: [{ source: 'erp', reference: 'binding:2:wrong' }], warnings: [] }, input.context)); });
