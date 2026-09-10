<script setup>
import { computed, onBeforeUnmount, ref, useId, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/jrcNicoKnowledge';

const props = defineProps({
  accountId: { type: [Number, String], required: true },
});
const { t } = useI18n();
const formId = useId();
const documents = ref([]);
const selected = ref(null);
const title = ref('');
const body = ref('');
const customerVisible = ref(false);
const reviewed = ref(false);
const busy = ref(false);
const error = ref(false);
let version = 0;
let controller;
const unchanged = computed(
  () =>
    selected.value &&
    title.value === selected.value.title &&
    body.value === selected.value.body &&
    customerVisible.value === selected.value.customer_visible
);
const select = document => {
  selected.value = document;
  title.value = document?.title || '';
  body.value = document?.body || '';
  customerVisible.value = document?.customer_visible || false;
  reviewed.value = false;
};
const execute = async action => {
  const captured = version;
  busy.value = true;
  error.value = false;
  try {
    await action(captured);
  } catch {
    if (captured === version) error.value = true;
  } finally {
    if (captured === version) busy.value = false;
  }
};
const load = async captured => {
  const { data } = await api.index(props.accountId, controller.signal);
  if (captured === version) documents.value = data;
};
const save = () =>
  execute(async captured => {
    const input = {
      title: title.value,
      body: body.value,
      customer_visible: customerVisible.value,
    };
    const { data } = selected.value
      ? await api.update(
          props.accountId,
          selected.value.id,
          input,
          controller.signal
        )
      : await api.create(props.accountId, input, controller.signal);
    if (captured !== version) return;
    select(data);
    await load(captured);
  });
const approve = () =>
  execute(async captured => {
    if (!unchanged.value || !reviewed.value) return;
    const { data } = await api.approve(
      props.accountId,
      selected.value.id,
      selected.value.digest,
      controller.signal
    );
    if (captured !== version) return;
    select(data);
    await load(captured);
  });
watch(
  () => props.accountId,
  () => {
    version += 1;
    controller?.abort();
    controller = new AbortController();
    documents.value = [];
    select(null);
    execute(load);
  },
  { immediate: true }
);
onBeforeUnmount(() => {
  version += 1;
  controller?.abort();
});
</script>

<template>
  <details class="rounded-xl border border-n-weak p-3 text-sm">
    <summary class="cursor-pointer font-semibold">
      {{ t('JRC_NICO.KNOWLEDGE.TITLE') }}
    </summary>
    <div class="mt-3 space-y-3">
      <p class="text-xs text-n-slate-11">
        {{ t('JRC_NICO.KNOWLEDGE.DESCRIPTION') }}
      </p>
      <p v-if="error" role="alert" class="text-n-ruby-11">
        {{ t('JRC_NICO.ERROR') }}
      </p>
      <div class="flex flex-wrap gap-2">
        <button
          type="button"
          class="rounded border border-n-weak px-2 py-1"
          :disabled="busy"
          @click="select(null)"
        >
          {{ t('JRC_NICO.KNOWLEDGE.NEW') }}
        </button>
        <button
          v-for="document in documents"
          :key="document.id"
          type="button"
          class="rounded border border-n-weak px-2 py-1"
          :disabled="busy"
          @click="select(document)"
        >
          {{ document.title }}
        </button>
      </div>
      <form class="space-y-2" @submit.prevent="save">
        <label :for="`${formId}-title`" class="block">{{
          t('JRC_NICO.KNOWLEDGE.NAME')
        }}</label>
        <input
          :id="`${formId}-title`"
          v-model="title"
          required
          maxlength="200"
          class="w-full rounded border border-n-weak bg-n-background p-2"
          :disabled="busy"
        />
        <label :for="`${formId}-body`" class="block">{{
          t('JRC_NICO.KNOWLEDGE.BODY')
        }}</label>
        <textarea
          :id="`${formId}-body`"
          v-model="body"
          required
          maxlength="20000"
          rows="7"
          class="w-full rounded border border-n-weak bg-n-background p-2"
          :disabled="busy"
        />
        <button
          type="submit"
          class="rounded bg-n-blue-10 px-3 py-2 text-white disabled:opacity-40"
          :disabled="busy || !title.trim() || !body.trim()"
        >
          {{ t('JRC_NICO.KNOWLEDGE.SAVE') }}
        </button>
        <label class="flex items-center gap-2 text-xs"
          ><input
            v-model="customerVisible"
            type="checkbox"
            :disabled="busy"
          />{{ t('JRC_NICO.KNOWLEDGE.CUSTOMER_VISIBLE') }}</label
        >
      </form>
      <p v-if="selected?.approved_at" class="text-xs text-n-teal-11">
        {{ t('JRC_NICO.KNOWLEDGE.APPROVED') }}
      </p>
      <template v-else-if="selected">
        <label class="flex items-start gap-2 text-xs">
          <input
            v-model="reviewed"
            type="checkbox"
            :disabled="!unchanged || busy"
          />
          <span>{{ t('JRC_NICO.KNOWLEDGE.REVIEW') }}</span>
        </label>
        <button
          type="button"
          class="rounded border border-n-weak px-3 py-2 disabled:opacity-40"
          :disabled="!unchanged || !reviewed || busy"
          @click="approve"
        >
          {{ t('JRC_NICO.KNOWLEDGE.APPROVE') }}
        </button>
      </template>
    </div>
  </details>
</template>
