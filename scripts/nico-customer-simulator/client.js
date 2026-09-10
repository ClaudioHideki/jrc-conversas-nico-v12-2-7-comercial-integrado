/* Local customer simulator. Uses only the existing public customer API. */
const element = id => document.getElementById(id);
const scenario = [
  'Olá! Sou Marina, da Loja Horizonte fictícia. Tenho interesse em uma solução de atendimento comercial. Pode me ajudar a entender o que vocês oferecem?',
  'Somos uma loja com 10 operadores. Hoje atendemos por WhatsApp e telefone, mas perdemos o histórico dos clientes. Precisamos centralizar as conversas e acompanhar as oportunidades no CRM.',
  'Queremos implantar em até 30 dias. O principal objetivo é organizar o histórico e distribuir melhor os atendimentos. Pode explicar como isso ajudaria nossa equipe no dia a dia?',
];
let config;
let messages = [];
let simulation = null;
let sending = false;
let lastSignature = '';
let waitingForMessage = null;
let connectionInterrupted = false;

function status(text) { element('status').textContent = text; }
function controls() {
  element('send').disabled = !config || sending || Boolean(simulation);
  element('simulate').disabled = !config || sending || Boolean(simulation);
  element('content').disabled = Boolean(simulation);
  element('stop').hidden = !simulation;
}
async function request(path, options = {}) {
  const response = await fetch(path, { ...options, cache: 'no-store', credentials: 'omit', signal: AbortSignal.timeout(15000) });
  if (!response.ok) throw new Error('Falha na conexão com o sistema (HTTP ' + response.status + ').');
  return response.json();
}
function render() {
  const visible = messages.filter(message => [0, 1].includes(message.message_type)).sort((a, b) => a.id - b.id);
  const signature = JSON.stringify(visible.map(message => [message.id, message.content]));
  if (signature === lastSignature) return;
  lastSignature = signature;
  const list = element('messages');
  const nearBottom = list.scrollHeight - list.scrollTop - list.clientHeight < 100;
  list.replaceChildren();
  if (!visible.length) {
    const empty = document.createElement('p');
    empty.className = 'my-auto text-center text-sm text-slate-500';
    empty.textContent = 'Envie a primeira mensagem para iniciar o teste.';
    list.append(empty);
  }
  for (const message of visible) {
    const incoming = message.message_type === 0;
    const nico = message.content_attributes?.nico_delegation;
    const bubble = document.createElement('article');
    bubble.className = incoming
      ? 'ml-auto w-fit max-w-[90%] rounded-2xl rounded-br-sm bg-blue-700 p-4 text-white'
      : 'mr-auto w-fit max-w-[90%] rounded-2xl rounded-bl-sm border border-slate-200 bg-white p-4 text-slate-800';
    const label = document.createElement('p');
    label.className = 'mb-1 text-xs font-bold';
    label.textContent = (incoming ? 'Você · Marina' : nico ? 'NICO · Assistente virtual' : 'Atendente humano') +
      ' · ' + new Date(message.created_at * 1000).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    const content = document.createElement('p');
    content.className = 'whitespace-pre-wrap break-words text-sm leading-relaxed';
    content.textContent = message.content || '[Anexo]';
    bubble.append(label, content);
    list.append(bubble);
  }
  if (nearBottom) list.scrollTop = list.scrollHeight;
}
async function refresh() {
  messages = await request(config.customer_path + '/messages');
  render();
  const reply = waitingForMessage && messages.find(message => message.id > waitingForMessage && message.message_type === 1);
  if (reply) {
    waitingForMessage = null;
    if (!simulation) {
      const control = reply.content_attributes?.nico_delegation;
      status(control?.handoff ? 'NICO encaminhou o atendimento ao humano.' : control ? 'Nova resposta do NICO recebida.' : 'Nova resposta do atendente recebida.');
    }
  }
}
async function send(content) {
  sending = true;
  controls();
  try {
    const result = await request(config.customer_path + '/messages', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content, echo_id: crypto.randomUUID() }),
    });
    waitingForMessage = result.id;
    messages.push(result);
    render();
    element('messages').scrollTop = element('messages').scrollHeight;
    return result;
  } finally {
    sending = false;
    controls();
  }
}
async function waitForReply(incomingId, run) {
  const deadline = Date.now() + 120000;
  while (simulation === run && Date.now() < deadline) {
    await refresh();
    const reply = messages.filter(message => message.id > incomingId && message.message_type === 1).sort((a, b) => a.id - b.id)[0];
    if (reply) {
      if (!reply.content_attributes?.nico_delegation || reply.content_attributes.nico_delegation.handoff) {
        throw new Error('Atendimento encaminhado ao humano. Cliente automático interrompido.');
      }
      return reply;
    }
    await new Promise(resolve => setTimeout(resolve, 2000));
  }
  if (simulation === run) throw new Error('O NICO não respondeu em 2 minutos. Confira se a conversa está delegada e o provedor está disponível.');
  return null;
}
element('composer').addEventListener('submit', async event => {
  event.preventDefault();
  if (sending || simulation || !config) return;
  const content = element('content').value.trim();
  if (!content) return;
  try {
    await send(content);
    element('content').value = '';
    status('Mensagem enviada. Aguardando o NICO ou o operador.');
  } catch (error) { status(error.message + ' Confira o histórico antes de reenviar.'); }
});
document.querySelectorAll('[data-preset]').forEach(button => button.addEventListener('click', () => {
  if (simulation) return;
  element('content').value = button.dataset.preset;
  element('content').focus();
}));
element('stop').addEventListener('click', () => {
  simulation = null;
  controls();
  status('Cliente automático parado. As mensagens já enviadas continuam na conversa.');
});
element('simulate').addEventListener('click', async () => {
  if (simulation || sending || !config) return;
  const run = {};
  simulation = run;
  controls();
  try {
    for (const [index, content] of scenario.entries()) {
      if (simulation !== run) return;
      status('Cliente automático: mensagem ' + (index + 1) + '/3. Aguardando resposta do NICO…');
      const incoming = await send(content);
      const reply = await waitForReply(incoming.id, run);
      if (!reply || simulation !== run) return;
    }
    status('Simulação concluída: 3 mensagens do cliente e 3 respostas novas do NICO.');
  } catch (error) {
    if (simulation === run) status(error.message);
  } finally {
    if (simulation === run) simulation = null;
    controls();
  }
});
async function poll() {
  if (config && !simulation && !document.hidden) {
    try {
      await refresh();
      if (connectionInterrupted) {
        connectionInterrupted = false;
        status(waitingForMessage ? 'Conexão restabelecida. Aguardando o NICO ou o operador.' : 'Conectado. As respostas aparecem automaticamente nesta tela.');
      }
    } catch (error) {
      connectionInterrupted = true;
      status(error.message);
    }
  }
  setTimeout(poll, 2500);
}
async function init() {
  try {
    config = await request('./config.json');
    element('name').textContent = config.name;
    element('reference').textContent = config.inbox_name + ' · Conversa #' + config.conversation_id;
    element('operator').href = config.operator_path;
    await refresh();
    status('Conectado. As respostas aparecem automaticamente nesta tela.');
    controls();
    poll();
  } catch (error) { config = null; controls(); status(error.message); }
}
init();
