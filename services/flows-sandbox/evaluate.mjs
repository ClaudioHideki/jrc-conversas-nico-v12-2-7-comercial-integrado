import { getQuickJS } from 'quickjs-emscripten';

export async function evaluate({ code, input, outputs = {}, parameters }) {
  const engine = await getQuickJS();
  // Only JSON crosses the WASM boundary. No host functions, filesystem, network,
  // environment, credentials, module loader or Node.js objects enter the guest.
  const context = engine.newContext();
  const deadline = Date.now() + 2000;
  context.runtime.setMemoryLimit(32 * 1024 * 1024);
  context.runtime.setMaxStackSize(512 * 1024);
  context.runtime.setInterruptHandler(() => Date.now() > deadline);
  try {
    const state = JSON.stringify({ input, outputs, parameters });
    const source = `
      const state = JSON.parse(${JSON.stringify(state)});
      const $input = { first: () => state.input[0], all: () => state.input, item: state.input[0] };
      const $json = state.input[0]?.json || {};
      const $ = name => { const items = state.outputs[name]; if (!items) throw new Error('Nó não executado: ' + name); return {first: () => items[0], all: () => items, item: items[0]}; };
      const $items = name => name ? $(name).all() : $input.all();
      const $node = new Proxy({}, {get: (_, name) => ({json: $(name).first().json})});
      const console = {log() {}, warn() {}, error() {}};
      const resolve = value => {
        if (Array.isArray(value)) return value.map(resolve);
        if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, resolve(v)]));
        if (typeof value !== 'string' || !value.startsWith('=')) return value;
        const expression = value.slice(1);
        const entire = expression.match(/^\\{\\{([\\s\\S]*)\\}\\}$/);
        if (entire) return eval('(' + entire[1] + ')');
        return expression.replace(/\\{\\{([\\s\\S]*?)\\}\\}/g, (_, expr) => String(eval('(' + expr + ')') ?? ''));
      };
      const result = ${parameters == null ? `(function() { ${code}\n })()` : 'resolve(state.parameters)'};
      if (result && typeof result.then === 'function') throw new Error('Use JavaScript síncrono');
      JSON.stringify(result);
    `;
    const result = context.evalCode(source);
    if (result.error) {
      const error = context.dump(result.error);
      result.error.dispose();
      throw new Error(String(error.message || 'Falha JavaScript').slice(0, 250));
    }
    const json = context.getString(result.value);
    result.value.dispose();
    if (json.length > 1000000) throw new Error('Saída excede 1 MB');
    return JSON.parse(json);
  } finally {
    context.dispose();
  }
}
