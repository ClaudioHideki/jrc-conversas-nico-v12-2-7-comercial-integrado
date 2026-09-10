<script setup>
import { computed, onBeforeUnmount, ref, useId, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import nicoAPI from 'dashboard/api/jrcNico';
import { createNicoRunSession } from './nicoRunSession';
import NicoKnowledgePanel from './NicoKnowledgePanel.vue';
import NicoProposalPanel from './NicoProposalPanel.vue';
import NicoErpPanel from './NicoErpPanel.vue';
import NicoAssistancePanel from './NicoAssistancePanel.vue';

const props = defineProps({
  accountId: { type: [String, Number], required: true },
  conversationId: { type: [String, Number], required: true },
  canManage: { type: Boolean, default: false },
});
const { t } = useI18n();
const inputId = useId();
const message = ref('');
const agents = ref([]);
const agentKey = ref('nico');
const selectedAgent = computed(() =>
  agents.value.find(agent => agent.key === agentKey.value)
);
const run = ref(null);
const loading = ref(false);
const submitting = ref(false);
const copied = ref(false);
let session;
let generation = 0;
const active = computed(() =>
  ['queued', 'running'].includes(run.value?.status)
);
const status = computed(
  () =>
    ({
      empty: t('JRC_NICO.STATUS.empty'),
      queued: t('JRC_NICO.STATUS.queued'),
      running: t('JRC_NICO.STATUS.running'),
      completed: t('JRC_NICO.STATUS.completed'),
      failed: t('JRC_NICO.STATUS.failed'),
      cancelled: t('JRC_NICO.STATUS.cancelled'),
    })[run.value?.status || 'empty']
);

const load = async () => {
  const version = generation;
  loading.value = true;
  await session.load();
  if (version === generation) loading.value = false;
};
const refreshErp = () => {
  generation += 1;
  session?.dispose();
  run.value = null;
  submitting.value = false;
  session = createNicoRunSession(
    nicoAPI,
    Number(props.accountId),
    Number(props.conversationId),
    value => {
      run.value = value;
    }
  );
  load();
};
const acceptSuggestedRun = value => {
  run.value = value;
  session.load();
};
watch(
  () => [props.accountId, props.conversationId],
  () => {
    generation += 1;
    session?.dispose();
    run.value = null;
    agents.value = [];
    agentKey.value = 'nico';
    message.value = '';
    submitting.value = false;
    session = createNicoRunSession(
      nicoAPI,
      Number(props.accountId),
      Number(props.conversationId),
      value => {
        run.value = value;
      }
    );
    load();
    const version = generation;
    nicoAPI
      .agents(props.accountId)
      .then(({ data }) => {
        if (version !== generation) return;
        agents.value = data;
        const preferred = sessionStorage.getItem('jrcNicoPreferredAgent');
        agentKey.value =
          data.find(agent => agent.key === preferred)?.key ||
          data.find(agent => agent.key === 'nico')?.key ||
          data[0]?.key ||
          '';
        sessionStorage.removeItem('jrcNicoPreferredAgent');
      })
      .catch(() => {
        if (version === generation) agents.value = [];
      });
  },
  { immediate: true }
);
const start = async () => {
  if (!message.value.trim() || submitting.value || active.value) return;
  const version = generation;
  submitting.value = true;
  await session.start(message.value.trim(), agentKey.value);
  if (version === generation) submitting.value = false;
};
const copyReply = async () => {
  await navigator.clipboard.writeText(run.value.result.suggested_reply);
  copied.value = true;
};
onBeforeUnmount(() => {
  generation += 1;
  session?.dispose();
});
</script>

<template>
  <section class="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto p-4">
    <NicoAssistancePanel
      :account-id="accountId"
      :conversation-id="conversationId"
      :can-manage="canManage"
      @authorized="acceptSuggestedRun"
    />
    <NicoErpPanel
      v-if="canManage"
      :key="`${accountId}:${conversationId}`"
      :account-id="accountId"
      :conversation-id="conversationId"
      @changed="refreshErp"
    />
    <p
      class="rounded-xl border border-n-weak bg-n-alpha-2 p-3 text-xs text-n-slate-11"
    >
      {{ t('JRC_NICO.ASSISTED') }}
    </p>
    <div class="flex items-center justify-between gap-2 text-sm">
      <strong>{{ loading ? t('JRC_NICO.LOADING') : status }}</strong>
      <button
        type="button"
        class="text-n-blue-11"
        :disabled="loading"
        @click="load"
      >
        {{ t('JRC_NICO.RELOAD') }}
      </button>
    </div>
    <p v-if="run?.agent_name" class="text-sm font-semibold">
      {{ run.agent_name }}
    </p>
    <p
      v-if="run?.network_error || run?.status === 'failed'"
      role="alert"
      class="rounded-lg bg-n-ruby-3 p-3 text-sm text-n-ruby-11"
    >
      {{ t('JRC_NICO.ERROR') }}
    </p>
    <p v-if="run?.message" class="whitespace-pre-wrap text-sm text-n-slate-11">
      {{ run.message }}
    </p>
    <template v-if="run?.status === 'completed'">
      <p
        v-if="run.result.mode === 'fixture'"
        role="status"
        class="rounded-xl border border-amber-400 bg-amber-50 p-3 text-sm text-amber-900"
      >
        {{ t('JRC_NICO.FIXTURE') }}
      </p>
      <p class="whitespace-pre-wrap text-sm text-n-slate-12">
        {{ run.result.summary }}
      </p>
      <label
        v-if="run.result.suggested_reply"
        class="flex flex-col gap-2 text-sm text-n-slate-11"
      >
        {{ t('JRC_NICO.SUGGESTED_REPLY') }}
        <textarea
          :value="run.result.suggested_reply"
          readonly
          rows="5"
          class="w-full rounded-lg border border-n-weak bg-n-background p-3"
        />
      </label>
      <button
        v-if="run.result.suggested_reply"
        type="button"
        class="rounded-lg border border-n-weak p-2 text-sm font-semibold text-n-blue-11"
        @click="copyReply"
      >
        {{ copied ? t('JRC_NICO.COPIED_REPLY') : t('JRC_NICO.COPY_REPLY') }}
      </button>
      <ul
        v-if="run.result.warnings?.length"
        class="list-disc space-y-1 pl-4 text-xs text-n-slate-11"
      >
        <li v-for="warning in run.result.warnings" :key="warning">
          {{ warning }}
        </li>
      </ul>
      <details
        v-if="run.result.evidence?.length"
        class="rounded-lg border border-n-weak p-3 text-xs text-n-slate-11"
      >
        <summary class="cursor-pointer">{{ t('JRC_NICO.EVIDENCE') }}</summary>
        <ul class="mt-2 space-y-1">
          <li
            v-for="item in run.result.evidence"
            :key="`${item.source}:${item.reference}`"
          >
            {{ t('JRC_NICO.REFERENCE', item) }}
          </li>
        </ul>
      </details>
      <NicoProposalPanel
        :key="`${accountId}:${run.id}`"
        :account-id="accountId"
        :run="run"
      />
    </template>
    <button
      v-if="active"
      type="button"
      class="rounded-lg border border-n-weak p-2 text-sm"
      @click="session.cancel()"
    >
      {{ t('JRC_NICO.CANCEL') }}
    </button>
    <NicoKnowledgePanel
      v-if="canManage"
      :key="accountId"
      :account-id="accountId"
    />
    <form class="mt-auto flex flex-col gap-2" @submit.prevent="start">
      <label class="flex flex-col gap-2 text-sm">
        {{ t('JRC_NICO.AGENT') }}
        <select
          v-model="agentKey"
          :disabled="active || submitting"
          class="w-full"
        >
          <option v-for="agent in agents" :key="agent.key" :value="agent.key">
            {{ agent.name }}
          </option>
        </select>
      </label>
      <p v-if="selectedAgent" class="text-xs text-n-slate-11">
        {{ selectedAgent.description }} {{ selectedAgent.limitation }}
      </p>
      <label :for="inputId" class="text-sm text-n-slate-11">{{
        t('JRC_NICO.PROMPT')
      }}</label>
      <textarea
        :id="inputId"
        v-model="message"
        maxlength="4000"
        rows="3"
        class="w-full rounded-xl border border-n-weak bg-n-background p-3 text-sm"
        :disabled="active || submitting"
      />
      <button
        type="submit"
        :disabled="
          active || submitting || loading || !message.trim() || !agents.length
        "
        class="rounded-xl bg-n-blue-10 px-4 py-3 text-sm font-semibold text-white disabled:opacity-40"
      >
        {{ t('JRC_NICO.ANALYZE') }}
      </button>
    </form>
  </section>
</template>
