import { writeFile } from 'node:fs/promises';
const base = new URL(process.env.NICO_PROVIDER_BASE_URL || 'https://api.openai.com/v1/');
if (base.origin !== 'https://api.openai.com') throw new Error('Unexpected provider');
const response = await fetch('https://api.openai.com/v1/audio/speech', {
  method: 'POST', headers: { Authorization: `Bearer ${process.env.NICO_PROVIDER_API_KEY}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ model: 'tts-1', input: 'Crie um contato de teste.', voice: 'alloy', response_format: 'wav' }),
  signal: AbortSignal.timeout(45000),
});
if (!response.ok) throw new Error(`Synthetic audio HTTP ${response.status}`);
const audio = Buffer.from(await response.arrayBuffer());
if (audio.length > 4194304) throw new Error('Audio too large');
await writeFile('qa-voice.wav', audio);
console.log(JSON.stringify({ synthetic: true, text: 'Crie um contato de teste.', bytes: audio.length }));
