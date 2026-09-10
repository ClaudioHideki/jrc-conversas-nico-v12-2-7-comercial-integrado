import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateInput, validateAnalysis } from '../src/contract.ts';

const input = {
  request_id: 'a56905c4-9a03-4c21-a886-b5d18a3e4c57', account_id: 1,
  agent_key: 'nico', message: 'Resuma', history: [],
  context: { conversation: [{ source: 'conversation', reference: 'message:10', text: 'Olá' }], crm: [], knowledge: [] },
};
const result = { summary: 'Cliente cumprimentou', suggested_reply: 'Como posso ajudar?', evidence: [{ source: 'conversation', reference: 'message:10' }], warnings: [] };

test('accepts bounded authorized context', () => assert.deepEqual(validateInput(input), input));
test('rejects arbitrary tools and account identity types', () => {
  assert.throws(() => validateInput({ ...input, tools: ['send_message'] }));
  assert.throws(() => validateInput({ ...input, account_id: '1' }));
  assert.throws(() => validateInput({ ...input, agent_key: 'arbitrary_admin' }));
});
test('rejects oversized content', () => assert.throws(() => validateInput({ ...input, message: 'a'.repeat(4001) })));
test('accepts only evidence supplied by Rails', () => {
  assert.deepEqual(validateAnalysis(result, input.context), result);
  assert.throws(() => validateAnalysis({ ...result, evidence: [{ source: 'crm', reference: 'deal:999' }] }, input.context));
});
test('rejects model side effects and malformed structured data', () => {
  assert.throws(() => validateAnalysis({ ...result, action: { send: 'yes' } }, input.context));
  assert.throws(() => validateAnalysis({ ...result, summary: null }, input.context));
});
test('does not coerce evidence or history types', () => {
  assert.throws(() => validateAnalysis({ ...result, evidence: [{ source: ['conversation'], reference: ['message:10'] }] }, input.context));
  assert.throws(() => validateInput({ ...input, history: [{ role: ['user'], content: 'x' }] }));
});

test('accepts all seven assisted specialists', () => {
  for (const agent_key of ['nico', 'comercial', 'cx', 'suporte_n1', 'financeiro', 'implantacao', 'supervisor']) {
    assert.equal(validateInput({ ...input, agent_key }).agent_key, agent_key);
  }
});

