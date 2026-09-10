import https from 'node:https';
import { ErpError } from './client.mjs';
export function transport(url, { headers, body }) {
  if (url.protocol !== 'https:' || !['api.ksys.net.br', 'api-bemtevi.ksys.net.br'].includes(url.hostname) || url.port || url.username || url.password) throw new ErpError('host_denied');
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const request = https.request(url, { method: 'GET', headers: { ...headers, ...(payload ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) } : {}) } }, response => {
      if (response.statusCode !== 200) { response.resume(); reject(new ErpError(`erp_http_${response.statusCode}`)); return; }
      const chunks = []; let size = 0;
      response.on('data', chunk => { size += chunk.length; if (size > 262144) request.destroy(new ErpError('response_too_large')); else chunks.push(chunk); });
      response.on('error', () => reject(new ErpError('transport_failed')));
      response.on('end', () => { try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch { reject(new ErpError('invalid_json')); } });
    });
    const deadline = setTimeout(() => request.destroy(new ErpError('erp_timeout')), 12000);
    request.on('close', () => clearTimeout(deadline));
    request.on('error', () => reject(new ErpError('transport_failed')));
    if (payload) request.write(payload);
    request.end();
  });
}
