import http from 'node:http';
import { Worker } from 'node:worker_threads';
import { timingSafeEqual } from 'node:crypto';

const token = process.env.JRC_FLOWS_SANDBOX_TOKEN;
if (!token || token.length < 32) throw new Error('Configure JRC_FLOWS_SANDBOX_TOKEN');
let active = 0;
http.createServer(async (req, res) => {
  const supplied = Buffer.from(req.headers.authorization || '');
  const expected = Buffer.from(`Bearer ${token}`);
  if (req.method !== 'POST' || supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
    res.writeHead(401).end();
    return;
  }
  if (active >= 4) { res.writeHead(429).end(); return; }
  active += 1;
  let worker;
  try {
    const chunks = [];
    let size = 0;
    for await (const chunk of req) {
      size += chunk.length;
      if (size > 2 * 1024 * 1024) throw new Error('Entrada excede 2 MB');
      chunks.push(chunk);
    }
    const data = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    worker = new Worker(new URL('./worker.mjs', import.meta.url), { workerData: data, resourceLimits: { maxOldGenerationSizeMb: 64 } });
    const result = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Tempo excedido')), 4000);
      worker.once('message', value => { clearTimeout(timer); resolve(value); });
      worker.once('error', error => { clearTimeout(timer); reject(error); });
      worker.once('exit', code => { if (code) { clearTimeout(timer); reject(new Error('Worker encerrado')); } });
    });
    res.writeHead(result.error ? 422 : 200, { 'Content-Type': 'application/json' }).end(JSON.stringify(result));
  } catch {
    res.writeHead(422, { 'Content-Type': 'application/json' }).end('{"error":"Execução interrompida"}');
  } finally {
    await worker?.terminate();
    active -= 1;
  }
}).listen(8080, '0.0.0.0');
