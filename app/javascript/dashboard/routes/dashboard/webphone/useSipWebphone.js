import { computed, ref, shallowRef } from 'vue';
import SipCredentialsAPI from 'dashboard/api/sipCredentials';
import { SipClient } from './SipClient';
import { normalizeSipDialNumber } from './phoneNumber';

const credential = ref(null);
const loading = ref(true);
const connecting = ref(false);
const status = ref('Desconectado');
const statusTone = ref('neutral');
const transport = ref('Desconectado');
const registration = ref('Não registrado');
const sessionState = ref('Sem chamada');
const destination = ref('');
const remoteNumber = ref('—');
const direction = ref('—');
const duration = ref('00:00');
const callId = ref('—');
const incoming = ref(false);
const sessionActive = ref(false);
const established = ref(false);
const muted = ref(false);
const held = ref(false);
const errorMessage = ref('');
const callEvents = ref([]);
const remoteStream = shallowRef(null);
const extensionEnabled = ref(true);
const reconnecting = ref(false);

const RECONNECT_DELAYS_MS = [1000, 2000, 5000, 10000, 30000];
const CONNECTION_WATCHDOG_MS = 20000;

let durationTimer;
let callStartedAt;
let activeAccountId;
let initializationPromise;
let initializationVersion = 0;
let reconnectTimer;
let reconnectAttempt = 0;
let intentionalDisconnect = false;
let networkListenersAttached = false;

const extensionStorageKey = accountId =>
  `jrc-softphone-extension:${accountId}:enabled`;

const readExtensionEnabled = accountId => {
  try {
    return (
      window.localStorage.getItem(extensionStorageKey(accountId)) !== 'false'
    );
  } catch {
    return true;
  }
};

const writeExtensionEnabled = (accountId, value) => {
  try {
    window.localStorage.setItem(extensionStorageKey(accountId), String(value));
  } catch {
    // localStorage can be unavailable in restricted browser contexts.
  }
};

export const formatCallDuration = totalSeconds => {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const minutePart = String(minutes % 60).padStart(2, '0');
  const secondPart = String(seconds).padStart(2, '0');
  return hours
    ? `${String(hours).padStart(2, '0')}:${minutePart}:${secondPart}`
    : `${String(minutes).padStart(2, '0')}:${secondPart}`;
};

const stopTimer = () => {
  if (durationTimer) window.clearInterval(durationTimer);
  durationTimer = undefined;
  callStartedAt = undefined;
  duration.value = '00:00';
};

const startTimer = () => {
  stopTimer();
  duration.value = '00:00';
  callStartedAt = Date.now();
  durationTimer = window.setInterval(() => {
    duration.value = formatCallDuration(
      Math.floor((Date.now() - callStartedAt) / 1000)
    );
  }, 1000);
};

const client = new SipClient({
  onStatus: value => {
    status.value = value.label;
    statusTone.value = value.tone;
  },
  onTransport: value => {
    transport.value = value;
    if (value === 'Desconectado' && !intentionalDisconnect) {
      registration.value = 'Não registrado';
      // The callback is registered before the reconnect coordinator is initialized.
      // eslint-disable-next-line no-use-before-define
      scheduleReconnect();
    }
  },
  onRegister: value => {
    registration.value = value;
    // The callback is registered before the reconnect coordinator is initialized.
    // eslint-disable-next-line no-use-before-define
    if (value === 'Registered') resetReconnectState();
    if (value === 'Terminated' && !intentionalDisconnect) {
      // eslint-disable-next-line no-use-before-define
      scheduleReconnect();
    }
  },
  onIncoming: ({ remote }) => {
    incoming.value = true;
    sessionActive.value = true;
    remoteNumber.value = remote;
    direction.value = 'entrada';
  },
  onSession: summary => {
    sessionState.value = summary.state;
    sessionActive.value = summary.state !== 'Terminated';
    remoteNumber.value = summary.remote;
    direction.value = summary.direction;
    callId.value = summary.callId;
  },
  onEstablished: () => {
    incoming.value = false;
    established.value = true;
    startTimer();
  },
  onEnded: () => {
    incoming.value = false;
    sessionActive.value = false;
    established.value = false;
    muted.value = false;
    held.value = false;
    remoteStream.value = null;
    stopTimer();
  },
  onMute: value => {
    muted.value = value;
  },
  onHold: value => {
    held.value = value;
  },
  onRemoteStream: stream => {
    remoteStream.value = stream;
  },
  onError: message => {
    errorMessage.value = message;
  },
  onLog: event => {
    callEvents.value = [...callEvents.value.slice(-5), event];
  },
});

const configured = computed(
  () => credential.value?.configured && credential.value?.enabled !== false
);
const registered = computed(() => registration.value === 'Registered');
const hasCall = computed(() => sessionActive.value);
const statusClass = computed(
  () =>
    ({
      success: 'bg-n-teal-3 text-n-teal-11 border-n-teal-7',
      warning: 'bg-n-amber-3 text-n-amber-11 border-n-amber-7',
      error: 'bg-n-ruby-3 text-n-ruby-11 border-n-ruby-7',
      neutral: 'bg-n-alpha-2 text-n-slate-11 border-n-weak',
    })[statusTone.value]
);

const run = async action => {
  errorMessage.value = '';
  try {
    return await action();
  } catch (error) {
    errorMessage.value = error?.message || 'Não foi possível concluir a ação.';
    return undefined;
  }
};

const canReconnect = () =>
  Boolean(
    activeAccountId &&
      configured.value &&
      extensionEnabled.value &&
      !intentionalDisconnect
  );

const clearReconnectTimer = () => {
  if (reconnectTimer) window.clearTimeout(reconnectTimer);
  reconnectTimer = undefined;
};

function resetReconnectState() {
  clearReconnectTimer();
  reconnectAttempt = 0;
  reconnecting.value = false;
}

function scheduleReconnect({ immediate = false } = {}) {
  if (
    !canReconnect() ||
    registered.value ||
    reconnectTimer ||
    connecting.value
  ) {
    return;
  }

  reconnecting.value = true;
  status.value =
    typeof navigator !== 'undefined' && navigator.onLine === false
      ? 'Sem internet. Aguardando reconexão'
      : 'Reconectando ramal';
  statusTone.value = 'warning';
  const delay = immediate
    ? 0
    : RECONNECT_DELAYS_MS[
        Math.min(reconnectAttempt, RECONNECT_DELAYS_MS.length - 1)
      ];
  reconnectTimer = window.setTimeout(() => {
    reconnectTimer = undefined;
    reconnectAttempt += 1;
    if (typeof navigator !== 'undefined' && navigator.onLine === false) {
      scheduleReconnect();
      return;
    }
    // connect is initialized after the reconnect scheduler.
    // eslint-disable-next-line no-use-before-define
    connect({ reconnect: true });
  }, delay);
}

const handleOnline = () => {
  if (!canReconnect() || registered.value) return;
  clearReconnectTimer();
  scheduleReconnect({ immediate: true });
};

const handleOffline = () => {
  if (!canReconnect()) return;
  status.value = 'Sem internet. Aguardando reconexão';
  statusTone.value = 'warning';
};

const attachNetworkListeners = () => {
  if (networkListenersAttached) return;
  window.addEventListener('online', handleOnline);
  window.addEventListener('offline', handleOffline);
  networkListenersAttached = true;
};

const detachNetworkListeners = () => {
  if (!networkListenersAttached) return;
  window.removeEventListener('online', handleOnline);
  window.removeEventListener('offline', handleOffline);
  networkListenersAttached = false;
};

const connect = async ({ reconnect = false } = {}) => {
  if (
    !configured.value ||
    !extensionEnabled.value ||
    connecting.value ||
    registered.value
  ) {
    return;
  }
  connecting.value = true;
  reconnecting.value = reconnect;
  intentionalDisconnect = true;
  let watchdogTimer;
  try {
    await Promise.race([
      client.connect(credential.value),
      new Promise((_, rejectConnection) => {
        watchdogTimer = window.setTimeout(
          () => rejectConnection(new Error('Tempo limite ao conectar o ramal')),
          CONNECTION_WATCHDOG_MS
        );
      }),
    ]);
    errorMessage.value = '';
  } catch (error) {
    errorMessage.value = error?.message || 'Não foi possível conectar o ramal.';
  } finally {
    if (watchdogTimer) window.clearTimeout(watchdogTimer);
    intentionalDisconnect = false;
    connecting.value = false;
    if (!registered.value) scheduleReconnect();
  }
};

const disconnect = async () => {
  clearReconnectTimer();
  reconnecting.value = false;
  intentionalDisconnect = true;
  try {
    return await run(() => client.disconnect());
  } finally {
    intentionalDisconnect = false;
  }
};
const turnOnExtension = async () => {
  if (!activeAccountId) return undefined;
  extensionEnabled.value = true;
  writeExtensionEnabled(activeAccountId, true);
  reconnectAttempt = 0;
  return connect();
};

const turnOffExtension = async () => {
  if (!activeAccountId || hasCall.value) return undefined;
  clearReconnectTimer();
  reconnecting.value = false;
  extensionEnabled.value = false;
  writeExtensionEnabled(activeAccountId, false);
  await disconnect();
  status.value = 'Ramal desligado';
  statusTone.value = 'neutral';
  return undefined;
};

const call = () => {
  callEvents.value = [];
  return run(() => client.call(normalizeSipDialNumber(destination.value)));
};
const answer = () => run(() => client.answer());
const reject = () => run(() => client.reject());
const hangup = () => run(() => client.hangup());
const setMuted = value => run(() => client.setMuted(value));
const setHold = value => run(() => client.setHold(value));
const transferCall = (type, transferDestination) =>
  run(() => client.transfer(type, transferDestination));

const pressKey = tone => {
  if (established.value) return run(() => client.sendDtmf(tone));
  if (!hasCall.value) destination.value += tone;
  return undefined;
};

const initialize = accountId => {
  if (!accountId) return Promise.resolve();
  attachNetworkListeners();
  if (initializationPromise && activeAccountId === accountId) {
    return initializationPromise;
  }
  if (activeAccountId === accountId && registered.value) {
    return Promise.resolve();
  }

  initializationVersion += 1;
  const version = initializationVersion;
  initializationPromise = (async () => {
    if (activeAccountId && activeAccountId !== accountId) {
      await disconnect();
    }
    activeAccountId = accountId;
    extensionEnabled.value = readExtensionEnabled(accountId);
    loading.value = true;
    try {
      const { data } = await SipCredentialsAPI.getMine();
      if (version !== initializationVersion) return;
      credential.value = data;
      if (data.configured && data.enabled !== false && extensionEnabled.value) {
        await connect();
      } else if (data.configured && data.enabled !== false) {
        status.value = 'Ramal desligado';
        statusTone.value = 'neutral';
      }
    } catch (error) {
      if (version !== initializationVersion) return;
      credential.value = { configured: false };
      errorMessage.value =
        error?.message || 'Não foi possível carregar a configuração SIP.';
    } finally {
      if (version === initializationVersion) {
        loading.value = false;
        initializationPromise = undefined;
      }
    }
  })();

  return initializationPromise;
};

const shutdown = async () => {
  stopTimer();
  clearReconnectTimer();
  reconnecting.value = false;
  intentionalDisconnect = true;
  detachNetworkListeners();
  activeAccountId = undefined;
  initializationVersion += 1;
  initializationPromise = undefined;
  try {
    if (client.userAgent) await client.disconnect();
  } finally {
    intentionalDisconnect = false;
  }
};

export const useSipWebphone = () => ({
  credential,
  loading,
  connecting,
  status,
  transport,
  registration,
  sessionState,
  destination,
  remoteNumber,
  direction,
  duration,
  callId,
  incoming,
  sessionActive,
  established,
  muted,
  held,
  errorMessage,
  callEvents,
  remoteStream,
  extensionEnabled,
  reconnecting,
  configured,
  registered,
  hasCall,
  statusClass,
  initialize,
  shutdown,
  connect,
  disconnect,
  turnOnExtension,
  turnOffExtension,
  call,
  answer,
  reject,
  hangup,
  setMuted,
  setHold,
  transferCall,
  pressKey,
});
