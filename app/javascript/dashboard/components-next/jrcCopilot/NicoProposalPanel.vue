<script setup>
import { computed, onBeforeUnmount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/jrcNicoProposals';

const props = defineProps({
  accountId: { type: [String, Number], required: true },
  run: { type: Object, required: true },
});
const { t } = useI18n();
const leads = computed(() =>
  props.run.result.evidence.filter(
    item => item.source === 'crm' && /^lead:\d+$/.test(item.reference)
  )
);
const leadId = ref('');
const title = ref('');
const dueAt = ref('');
const actionKind = ref(props.run.allowed_actions?.[0] || 'follow_up');
const reviewed = ref(false);
const proposal = ref(null);
const busy = ref(false);
const error = ref(false);
const controller = new AbortController();
let alive = true;
let requestId;
let lastInput;
const preview = async () => {
  if (busy.value) return;
  const input = {
    run_id: props.run.id,
    lead_id: Number(leadId.value),
    title: title.value,
    due_at: new Date(dueAt.value).toISOString(),
    action_kind: actionKind.value,
  };
  if (JSON.stringify(input) !== lastInput) {
    requestId = crypto.randomUUID();
    lastInput = JSON.stringify(input);
  }
  busy.value = true;
  error.value = false;
  try {
    const response = await api.create(
      props.accountId,
      { ...input, request_id: requestId },
      controller.signal
    );
    if (alive) {
      proposal.value = response.data;
      reviewed.value = false;
    }
  } catch {
    if (alive) error.value = true;
  } finally {
    if (alive) busy.value = false;
  }
};
const approve = async () => {
  if (!reviewed.value || busy.value) return;
  busy.value = true;
  error.value = false;
  try {
    const response = await api.approve(
      props.accountId,
      proposal.value.id,
      proposal.value.digest,
      controller.signal
    );
    if (alive) proposal.value = response.data;
  } catch {
    if (alive) error.value = true;
  } finally {
    if (alive) busy.value = false;
  }
};
onBeforeUnmount(() => {
  alive = false;
  controller.abort();
});
</script>

<template>
  <details
    v-show="leads.length"
    class="rounded-xl border border-n-weak p-3 text-sm"
  >
    <summary class="cursor-pointer">{{ t('JRC_NICO.ACTION.TITLE') }}</summary>
    <p v-if="error" role="alert" class="my-2 text-n-ruby-11">
      {{ t('JRC_NICO.ERROR') }}
    </p>
    <form
      v-if="!proposal"
      class="mt-3 flex flex-col gap-3"
      @submit.prevent="preview"
    >
      <label class="flex flex-col gap-2">
        <span>{{ t('JRC_NICO.ACTION.KIND') }}</span>
        <select v-model="actionKind" class="w-full">
          <option
            v-for="kind in run.allowed_actions || ['follow_up']"
            :key="kind"
            :value="kind"
          >
            {{ t(`JRC_NICO.ACTION.KINDS.${kind}`) }}
          </option>
        </select>
      </label>
      <label class="flex flex-col gap-2">
        <span>{{ t('JRC_NICO.ACTION.LEAD') }}</span>
        <select v-model="leadId" required class="w-full">
          <option
            v-for="lead in leads"
            :key="lead.reference"
            :value="lead.reference.split(':')[1]"
          >
            {{ lead.reference }}
          </option>
        </select>
      </label>
      <label class="flex flex-col gap-2">
        <span>{{ t('JRC_NICO.ACTION.NAME') }}</span>
        <input v-model="title" required maxlength="200" class="w-full" />
      </label>
      <label class="flex flex-col gap-2">
        <span>{{ t('JRC_NICO.ACTION.DUE') }}</span>
        <input v-model="dueAt" required type="datetime-local" class="w-full" />
      </label>
      <button :disabled="busy" class="rounded-lg border p-2">
        {{ t('JRC_NICO.ACTION.PREVIEW') }}
      </button>
    </form>
    <div v-else class="mt-3 flex flex-col gap-3">
      <p>
        {{
          t(
            `JRC_NICO.ACTION.KINDS.${proposal.payload.action_kind || 'follow_up'}`
          )
        }}
      </p>
      <p v-if="proposal.payload.action_kind === 'create_deal'">
        {{ t('JRC_NICO.ACTION.DEAL_NOTICE') }}
      </p>
      <p>{{ proposal.payload.title }}</p>
      <p>
        {{
          t('JRC_NICO.ACTION.DETAIL', {
            lead: proposal.payload.lead_id,
            due: new Date(proposal.payload.due_at).toLocaleString(),
          })
        }}
      </p>
      <p v-if="proposal.status === 'executed'" role="status">
        {{ t('JRC_NICO.ACTION.DONE') }}
      </p>
      <template v-else>
        <label class="flex gap-2">
          <input v-model="reviewed" type="checkbox" />
          <span>{{ t('JRC_NICO.ACTION.REVIEW') }}</span>
        </label>
        <button
          :disabled="!reviewed || busy"
          class="rounded-lg bg-n-blue-10 p-2 text-white disabled:opacity-40"
          @click="approve"
        >
          {{ t('JRC_NICO.ACTION.APPROVE') }}
        </button>
        <button :disabled="busy" @click="proposal = null">
          {{ t('JRC_NICO.ACTION.EDIT') }}
        </button>
      </template>
    </div>
  </details>
</template>
