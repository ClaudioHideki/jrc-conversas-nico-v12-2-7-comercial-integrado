import { parentPort, workerData } from 'node:worker_threads';
import { evaluate } from './evaluate.mjs';

try {
  parentPort.postMessage({ result: await evaluate(workerData) });
} catch (error) {
  parentPort.postMessage({ error: error.message });
}
