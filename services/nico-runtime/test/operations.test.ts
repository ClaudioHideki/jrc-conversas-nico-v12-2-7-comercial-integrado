import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createEngine } from '../src/engine.ts';
import { operationPrompt, validateOperation, validateOperationResult } from '../src/operations.ts';
import { validateAudio, transcribeAudio } from '../src/transcription.ts';

const input = { request_id: 'a56905c4-9a03-4c21-a886-b5d18a3e4c57', account_id: 1, kind: 'operator' as const, message: 'Crie um contato', history: [], context: {} };
test('operation boundary rejects unknown scope and non-object tool arguments', () => {
  assert.throws(() => validateOperation({ ...input, account_id: 0 }));
  assert.throws(() => validateOperation({ ...input, kind: 'execute_arbitrary' }));
  assert.throws(() => validateOperation({ ...input, secret: 'no' }));
  for (const value of ['true', '1', '[]', 'null', '"text"']) {
    assert.throws(() => validateOperationResult({ reply: '', tool: 'create_contact', arguments: value }, 'operator'));
  }
  assert.equal(validateOperationResult({ reply: 'Qual nome?', tool: '', arguments: '' }, 'operator').arguments, '{}');
});
test('operator prompt forbids claiming actions without real tool evidence', () => {
  const prompt = operationPrompt('operator');
  assert.match(prompt, /Se tool estiver vazio/);
  assert.match(prompt, /Nunca diga que consultou, encontrou, criou, atualizou, moveu, enviou, agendou ou executou algo sem uma ferramenta correspondente realmente executada/);
  assert.match(prompt, /use uma ferramenta de consulta em vez de responder por suposicao/);
});

test('three independent operations share bounded capacity but not cancellation', { timeout: 60000 }, async () => {
  const dir = await mkdtemp(join(tmpdir(), 'nico-operations-'));
  const engine = await createEngine({ mode: 'provider', dataDir: dir, model: 'test-model', apiKey: 'test-only' });
  const original = globalThis.fetch;
  const pending: Array<{ resolve: (value: Response) => void }> = [];
  let allStarted!: () => void;
  const started = new Promise<void>(resolve => { allStarted = resolve; });
  try {
    globalThis.fetch = async (_url, options) => new Promise((resolve, reject) => {
      pending.push({ resolve });
      options?.signal?.addEventListener('abort', () => reject(new Error('cancelled')), { once: true });
      if (pending.length === 3) allStarted();
    });
    const cancellation = new AbortController();
    const first = engine.operate(input, cancellation.signal);
    const second = engine.operate({ ...input, message: 'Cliente dois' });
    const third = engine.operate({ ...input, message: 'Cliente três' });
    const rejected = assert.rejects(first);
    await started;
    await assert.rejects(engine.operate(input), /Runtime busy/);
    cancellation.abort();
    await rejected;
    for (let index = 1; index <= 2; index++) {
      pending[index].resolve(Response.json({ choices: [{ message: { content: JSON.stringify({ reply: `Resposta ${index}`, tool: '', arguments: '{}' }) } }], usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 } }));
    }
    assert.equal((await second as any).reply, 'Resposta 1');
    assert.equal((await third as any).reply, 'Resposta 2');
  } finally {
    globalThis.fetch = original;
    await engine.close();
    await rm(dir, { recursive: true, force: true });
  }
});
test('audio uses bounded multipart upload with accounting, without returning an action', async () => {
  const audio = { request_id: input.request_id, account_id: 1, mime_type: 'audio/webm', audio_base64: Buffer.from('audio-test-data-only').toString('base64') };
  assert.throws(() => validateAudio({ ...audio, mime_type: 'text/html' }));
  assert.throws(() => validateAudio({ ...audio, audio_base64: '!!!' }));
  assert.throws(() => validateAudio({ ...audio, url: 'https://external.test' }));
  const original = globalThis.fetch;
  try {
    globalThis.fetch = async (url, options) => {
      assert.equal(url, 'https://api.openai.com/v1/audio/transcriptions');
      assert.ok(options?.body instanceof FormData);
      assert.equal((options.body as FormData).get('language'), 'pt');
      return Response.json({ text: 'Crie um contato', usage: { type: 'tokens', input_tokens: 100, output_tokens: 5, total_tokens: 105 } });
    };
    const result = await transcribeAudio(audio, { mode: 'provider', apiKey: 'test-only' });
    assert.equal(result.text, 'Crie um contato');
    assert.equal(result.usage.total_tokens, 105);
    assert.equal('tool' in result, false);
    await assert.rejects(transcribeAudio(audio, { mode: 'fixture' }));
  } finally { globalThis.fetch = original; }
});
