<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { createJrcBrokerApi } from 'dashboard/api/jrcBroker';
import Button from 'dashboard/components-next/button/Button.vue';
import ConnectionPanel from './ConnectionPanel.vue';

const props = defineProps({ accountId: { type: Number, required: true } });
const { t } = useI18n();
const resources = ref(null);
const operations = ref([]);
const operation = ref(null);
const bindingReady = ref(false);
const adoptedInbox = ref(null);
const name = ref('');
const source = ref('EXISTING');
const instanceId = ref('');
const instanceName = ref('');
const providerAccountId = ref('');
const agentIds = ref([]);
const busy = ref(false);
const error = ref('');
const uncertain = ref(false);
const api = createJrcBrokerApi(props.accountId);
const controller = new AbortController();
let disposed = false;
let intent;
let timer;
let generation = 0;
let failures = 0;

const refreshOperations = async () => {
  const value = await api.operations(controller.signal);
  if (!disposed) operations.value = value.data;
};
const poll = async () => {
  clearTimeout(timer);
  if (disposed || document.hidden || !operation.value) return;
  const current = generation;
  try {
    const value = await api.operation(
      operation.value.operationId,
      controller.signal
    );
    if (disposed || current !== generation) return;
    operation.value = value;
    bindingReady.value = value.state === 'SUCCEEDED';
    failures = 0;
    error.value = '';
  } catch (failure) {
    if (disposed || current !== generation) return;
    error.value = [401, 403, 404].includes(failure?.response?.status)
      ? 'DENIED'
      : 'UNAVAILABLE';
    bindingReady.value = false;
    failures += 1;
  } finally {
    if (
      !disposed &&
      current === generation &&
      ['PENDING', 'RUNNING'].includes(operation.value?.state) &&
      error.value !== 'DENIED'
    ) {
      timer = setTimeout(poll, Math.min(15000, 3000 * (failures + 1)));
    }
  }
};
const resume = value => {
  generation += 1;
  bindingReady.value = false;
  operation.value = value;
  uncertain.value = false;
  intent = undefined;
  poll();
};
const create = async () => {
  if (busy.value) return;
  busy.value = true;
  error.value = '';
  if (!intent) {
    intent = {
      key: crypto.randomUUID(),
      body: {
        name: name.value,
        source:
          source.value === 'EXISTING'
            ? { kind: 'EXISTING', instanceId: instanceId.value }
            : {
                kind: 'NEW',
                instanceName: instanceName.value,
                providerAccountId: providerAccountId.value,
              },
        agentIds: [...agentIds.value],
        replaceExistingWebhook: false,
      },
    };
  }
  try {
    const value = await api.create(intent.body, intent.key, controller.signal);
    if (!disposed) resume(value);
  } catch (failure) {
    if (!disposed) {
      const rejected = [400, 401, 403, 404, 422].includes(
        failure?.response?.status
      );
      uncertain.value = !rejected;
      error.value = rejected ? 'INVALID_SETUP' : 'UNAVAILABLE';
      if (rejected) intent = undefined;
    }
    await refreshOperations().catch(() => {});
  } finally {
    if (!disposed) busy.value = false;
  }
};
const recover = async action => {
  if (busy.value) return;
  busy.value = true;
  const current = generation;
  try {
    const value = await api.recover(
      operation.value.operationId,
      action,
      crypto.randomUUID(),
      controller.signal
    );
    if (!disposed && current === generation) resume(value);
  } catch {
    if (!disposed) error.value = 'UNAVAILABLE';
  } finally {
    if (!disposed) busy.value = false;
  }
};
const newSetup = () => {
  generation += 1;
  clearTimeout(timer);
  operation.value = null;
  refreshOperations().catch(() => {
    error.value = 'UNAVAILABLE';
  });
};
const adopt = async integrationId => {
  if (busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    const result = await api.adopt(integrationId, controller.signal);
    if (!disposed) adoptedInbox.value = result.inboxId;
  } catch {
    if (!disposed) error.value = 'INVALID_SETUP';
  } finally {
    if (!disposed) busy.value = false;
  }
};
const visibility = () => {
  clearTimeout(timer);
  if (!document.hidden) poll();
};
onMounted(async () => {
  document.addEventListener('visibilitychange', visibility);
  try {
    const [available] = await Promise.all([
      api.resources(controller.signal),
      refreshOperations(),
    ]);
    if (!disposed) resources.value = available;
  } catch {
    if (!disposed) error.value = 'UNAVAILABLE';
  }
});
onBeforeUnmount(() => {
  disposed = true;
  generation += 1;
  controller.abort();
  clearTimeout(timer);
  document.removeEventListener('visibilitychange', visibility);
});
</script>

<template>
  <section class="flex flex-col gap-5">
    <p v-if="error" role="alert">{{ t(`JRC_BROKER.ERROR.${error}`) }}</p>
    <ConnectionPanel
      v-if="adoptedInbox"
      :account-id="accountId"
      :inbox-id="adoptedInbox"
    />
    <section
      v-if="!operation && resources?.connections?.length"
      class="flex flex-col gap-3"
    >
      <p>{{ t('JRC_BROKER.ADOPT_HELP') }}</p>
      <Button
        v-for="connection in resources.connections"
        :key="connection.integrationId"
        :label="t('JRC_BROKER.ADOPT', { name: connection.name })"
        :disabled="busy"
        @click="adopt(connection.integrationId)"
      />
    </section>
    <template v-if="operation">
      <div
        class="rounded-xl border border-n-weak p-5 flex flex-col gap-3"
        aria-live="polite"
      >
        <p>{{ t(`JRC_BROKER.STATUS.${operation.state}`) }}</p>
        <p>
          {{ t('JRC_BROKER.STAGE') }}
          {{ t(`JRC_BROKER.STAGES.${operation.stage}`) }}
        </p>
        <p v-if="operation.state === 'UNKNOWN'">
          {{ t('JRC_BROKER.UNKNOWN_HELP') }}
        </p>
        <Button
          v-if="operation.state === 'FAILED'"
          :disabled="busy"
          :label="t('JRC_BROKER.RETRY')"
          @click="recover('RETRY')"
        />
        <Button
          v-if="operation.state === 'UNKNOWN'"
          :disabled="busy"
          :label="t('JRC_BROKER.RECONCILE')"
          @click="recover('RECONCILE')"
        />
        <Button
          v-if="['FAILED', 'UNKNOWN'].includes(operation.state)"
          variant="outline"
          :disabled="busy"
          :label="t('JRC_BROKER.CANCEL_SETUP')"
          @click="recover('CANCEL')"
        />
        <Button
          v-if="['FAILED', 'SUCCEEDED'].includes(operation.state)"
          variant="outline"
          :disabled="busy"
          :label="t('JRC_BROKER.NEW_SETUP')"
          @click="newSetup"
        />
      </div>
      <ConnectionPanel
        v-if="bindingReady && operation.inboxId"
        :key="operation.operationId"
        :account-id="accountId"
        :inbox-id="operation.inboxId"
      />
      <RouterLink
        v-if="bindingReady"
        :to="{
          name: 'settings_inbox_show',
          params: { accountId, inboxId: operation.inboxId },
        }"
      >
        {{ t('JRC_BROKER.OPEN_SETTINGS') }}
      </RouterLink>
    </template>
    <template v-else>
      <p v-if="uncertain" role="status">{{ t('JRC_BROKER.UNCERTAIN') }}</p>
      <form
        v-if="resources"
        class="rounded-xl border border-n-weak p-5 flex flex-col gap-4"
        @submit.prevent="create"
      >
        <fieldset :disabled="busy || uncertain" class="flex flex-col gap-4">
          <label class="flex flex-col gap-2">
            <span>{{ t('JRC_BROKER.INBOX_NAME') }}</span>
            <input v-model.trim="name" required maxlength="100" />
          </label>
          <label class="flex flex-col gap-2">
            <span>{{ t('JRC_BROKER.SOURCE') }}</span>
            <select v-model="source">
              <option value="EXISTING">{{ t('JRC_BROKER.EXISTING') }}</option>
              <option value="NEW">{{ t('JRC_BROKER.NEW') }}</option>
            </select>
          </label>
          <label v-if="source === 'EXISTING'" class="flex flex-col gap-2">
            <span>{{ t('JRC_BROKER.EXISTING') }}</span>
            <select v-model="instanceId" required>
              <option
                v-for="value in resources.instances"
                :key="value.id"
                :value="value.id"
              >
                {{ value.name }}
              </option>
            </select>
          </label>
          <template v-else>
            <label class="flex flex-col gap-2">
              <span>{{ t('JRC_BROKER.INSTANCE_NAME') }}</span>
              <input v-model.trim="instanceName" required maxlength="100" />
            </label>
            <label class="flex flex-col gap-2">
              <span>{{ t('JRC_BROKER.PROVIDER') }}</span>
              <select v-model="providerAccountId" required>
                <option
                  v-for="value in resources.providers"
                  :key="value.id"
                  :value="value.id"
                >
                  {{ value.name }}
                </option>
              </select>
            </label>
          </template>
          <fieldset class="flex flex-col gap-2">
            <legend>{{ t('JRC_BROKER.AGENTS') }}</legend>
            <label
              v-for="agent in resources.agents"
              :key="agent.id"
              class="flex items-center gap-2"
            >
              <input v-model="agentIds" type="checkbox" :value="agent.id" />
              <span>{{ agent.name }}</span>
            </label>
          </fieldset>
        </fieldset>
        <Button
          data-testid="create"
          type="submit"
          :disabled="busy"
          :label="
            t(uncertain ? 'JRC_BROKER.RETRY_INTENT' : 'JRC_BROKER.CREATE')
          "
        />
      </form>
      <h3>{{ t('JRC_BROKER.OPERATIONS') }}</h3>
      <div
        v-for="value in operations"
        :key="value.operationId"
        class="flex flex-wrap items-center justify-between gap-3 border border-n-weak p-3 rounded-lg"
      >
        <div class="flex gap-2">
          <span>{{ t(`JRC_BROKER.STATUS.${value.state}`) }}</span>
          <span>{{ value.operationId.slice(0, 8) }}</span>
        </div>
        <Button
          variant="outline"
          :disabled="busy"
          :label="t('JRC_BROKER.RESUME')"
          @click="resume(value)"
        />
      </div>
    </template>
  </section>
</template>
