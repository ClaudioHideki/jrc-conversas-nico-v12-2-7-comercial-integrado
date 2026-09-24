<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { createJrcBrokerApi } from 'dashboard/api/jrcBroker';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  isPairingActionUsable,
  pairingImage,
  visibleConnectionActions,
} from './pairingState';

const props = defineProps({
  accountId: { type: Number, required: true },
  inboxId: { type: Number, required: true },
});
const { t } = useI18n();
const store = useStore();
const health = ref(null);
const action = ref(null);
const error = ref('');
const busy = ref(false);
const expired = ref(false);
const confirm = ref('');
const approved = ref(false);
const actions = computed(() =>
  visibleConnectionActions(health.value?.allowedActions)
);
const image = computed(() => pairingImage(action.value));
let api;
let controller;
let generation = 0;
let timer;
let expiryTimer;
let stopped = false;
let failures = 0;
let latestPoll = 0;
let confirmationRevision;
let pendingPair;

const clearCode = () => {
  pendingPair = null;
  clearTimeout(expiryTimer);
  action.value = null;
};

const acceptPair = (result, key) => {
  if (isPairingActionUsable(result.action, Date.now())) {
    pendingPair = null;
    action.value = result.action;
    expiryTimer = setTimeout(
      () => {
        clearCode();
        expired.value = true;
      },
      Date.parse(result.action.expiresAt) - Date.now()
    );
  } else if (result.action?.reason === 'CONNECTION_PENDING') {
    pendingPair ||= { key, expiresAt: Date.now() + 60000 };
  } else {
    pendingPair = null;
  }
};

const stop = () => {
  generation += 1;
  stopped = true;
  clearTimeout(timer);
  clearCode();
  controller?.abort();
  health.value = null;
  busy.value = false;
  confirm.value = '';
  approved.value = false;
};
const fail = failure => {
  clearCode();
  const denied = [401, 403, 404].includes(failure?.response?.status);
  if (denied) stop();
  error.value = denied ? 'DENIED' : 'UNAVAILABLE';
};
const poll = async () => {
  clearTimeout(timer);
  if (stopped || document.hidden) return;
  const current = generation;
  latestPoll += 1;
  const pollVersion = latestPoll;
  try {
    const result = await api.status(props.inboxId, controller.signal);
    if (current !== generation || pollVersion !== latestPoll) return;
    if (
      confirm.value === 'confirmIdentity' &&
      result.identityRevision !== confirmationRevision
    ) {
      confirm.value = '';
      approved.value = false;
    }
    health.value = result;
    failures = 0;
    error.value = '';
    if (
      result.instanceStatus === 'CONNECTED' ||
      !actions.value.includes('pair')
    )
      clearCode();
    if (pendingPair && Date.now() >= pendingPair.expiresAt) {
      pendingPair = null;
      expired.value = true;
    }
    if (pendingPair && !busy.value) {
      const key = pendingPair.key;
      const pairing = await api.pair(props.inboxId, key, controller.signal);
      if (current !== generation || pollVersion !== latestPoll) return;
      acceptPair(pairing, key);
    }
  } catch (failure) {
    if (current !== generation || pollVersion !== latestPoll) return;
    failures += 1;
    fail(failure);
  } finally {
    if (
      current === generation &&
      pollVersion === latestPoll &&
      !stopped &&
      !document.hidden
    )
      timer = setTimeout(poll, Math.min(15000, 3000 * (failures + 1)));
  }
};
const mutate = async kind => {
  if (
    busy.value ||
    stopped ||
    !actions.value.includes(kind === 'confirmIdentity' ? 'manage' : kind)
  )
    return;
  if (kind !== 'pair' && !approved.value) return;
  if (
    kind === 'confirmIdentity' &&
    confirmationRevision !== health.value?.identityRevision
  )
    return;
  const current = generation;
  busy.value = true;
  error.value = '';
  expired.value = false;
  clearCode();
  try {
    const key = crypto.randomUUID();
    const result =
      kind === 'confirmIdentity'
        ? await api.confirmIdentity(
            props.inboxId,
            confirmationRevision,
            key,
            controller.signal
          )
        : await api[kind](props.inboxId, key, controller.signal);
    if (current !== generation) return;
    if (kind === 'pair') acceptPair(result, key);
    confirm.value = '';
    approved.value = false;
    await poll();
  } catch (failure) {
    if (current === generation) fail(failure);
  } finally {
    if (current === generation) busy.value = false;
  }
};
const restart = () => {
  stop();
  stopped = false;
  failures = 0;
  error.value = '';
  expired.value = false;
  controller = new AbortController();
  api = createJrcBrokerApi(props.accountId);
  poll();
};
const openConfirmation = kind => {
  confirmationRevision = health.value?.identityRevision;
  confirm.value = kind;
  approved.value = false;
};
const visibility = () => {
  clearTimeout(timer);
  if (!document.hidden && !stopped) poll();
};
watch(() => [props.accountId, props.inboxId], restart, { immediate: true });
const unsubscribe = store?.subscribe(mutation => {
  if (mutation.type === 'LOGOUT') stop();
});
onMounted(() => document.addEventListener('visibilitychange', visibility));
onBeforeUnmount(() => {
  stop();
  unsubscribe?.();
  document.removeEventListener('visibilitychange', visibility);
});
</script>

<template>
  <section
    class="flex flex-col gap-4 p-5 border border-n-weak rounded-xl bg-n-solid-1"
    :aria-label="t('JRC_BROKER.TITLE')"
  >
    <h3 class="text-lg font-semibold text-n-slate-12">
      {{ t('JRC_BROKER.TITLE') }}
    </h3>
    <p v-if="error" role="alert">{{ t(`JRC_BROKER.ERROR.${error}`) }}</p>
    <dl v-if="health" class="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm">
      <div>
        <dt>{{ t('JRC_BROKER.CONFIGURATION') }}</dt>
        <dd>{{ t(`JRC_BROKER.STATUS.${health.integrationStatus}`) }}</dd>
      </div>
      <div>
        <dt>{{ t('JRC_BROKER.NUMBER') }}</dt>
        <dd>{{ t(`JRC_BROKER.STATUS.${health.instanceStatus}`) }}</dd>
      </div>
      <div>
        <dt>{{ t('JRC_BROKER.TRANSPORT') }}</dt>
        <dd>{{ t(`JRC_BROKER.STATUS.${health.transportStatus}`) }}</dd>
      </div>
    </dl>
    <p
      v-if="health?.transportStatus !== 'OPERATIONAL'"
      class="text-sm text-n-slate-11"
    >
      {{ t('JRC_BROKER.UNVERIFIED_HELP') }}
    </p>
    <img
      v-if="image"
      :src="image"
      :alt="t('JRC_BROKER.QR_ALT')"
      class="w-64 h-64 max-w-full self-center bg-white p-2"
    />
    <output
      v-else-if="action?.type === 'PAIRING_CODE'"
      class="text-2xl font-mono text-center"
    >
      <span>{{ action.code }}</span>
    </output>
    <p v-if="expired" role="status">{{ t('JRC_BROKER.EXPIRED') }}</p>
    <div class="flex flex-wrap gap-3">
      <Button
        v-if="actions.includes('pair')"
        data-testid="pair"
        :disabled="busy"
        :label="t('JRC_BROKER.PAIR')"
        @click="mutate('pair')"
      />
      <Button
        v-if="actions.includes('disconnect')"
        :disabled="busy"
        variant="outline"
        :label="t('JRC_BROKER.DISCONNECT')"
        @click="openConfirmation('disconnect')"
      />
      <Button
        v-if="
          actions.includes('manage') &&
          health?.identityStatus === 'CONFIRMATION_REQUIRED'
        "
        :disabled="busy"
        variant="outline"
        :label="t('JRC_BROKER.CONFIRM_IDENTITY')"
        @click="openConfirmation('confirmIdentity')"
      />
    </div>
    <div
      v-if="confirm"
      class="p-4 border border-n-weak rounded-lg flex flex-col gap-3"
    >
      <p>
        {{
          confirm === 'disconnect'
            ? t('JRC_BROKER.DISCONNECT_WARNING')
            : t('JRC_BROKER.IDENTITY_WARNING', {
                suffix: health?.observedNumberSuffix || '—',
              })
        }}
      </p>
      <label class="flex gap-2 items-center">
        <input v-model="approved" type="checkbox" />
        <span>{{ t('JRC_BROKER.UNDERSTAND') }}</span>
      </label>
      <div class="flex gap-3">
        <Button
          :disabled="busy || !approved"
          :label="t('JRC_BROKER.CONFIRM')"
          @click="mutate(confirm)"
        />
        <Button
          variant="outline"
          :label="t('JRC_BROKER.CANCEL')"
          @click="
            confirm = '';
            approved = false;
          "
        />
      </div>
    </div>
  </section>
</template>
