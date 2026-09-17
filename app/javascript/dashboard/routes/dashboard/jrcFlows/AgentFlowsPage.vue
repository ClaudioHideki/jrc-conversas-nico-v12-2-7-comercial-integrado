<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import api from 'dashboard/api/jrcFlows';
import messages from './workspace.en.json';

const { t } = useI18n({
  useScope: 'local',
  messages: { en: messages, pt_BR: messages, pt: messages },
});
const { accountId } = useAccount();
const flows = ref([]);
const inboxes = ref([]);
const runs = ref([]);
const selected = ref(null);
const loading = ref(false);
const error = ref('');
let generation = 0;
onBeforeUnmount(() => {
  generation += 1;
});
async function load() {
  const current = ++generation;
  loading.value = true;
  error.value = '';
  selected.value = null;
  runs.value = [];
  try {
    const [list, metadata] = await Promise.all([api.get(), api.metadata()]);
    if (current !== generation) return;
    flows.value = list.data;
    inboxes.value = metadata.data.inboxes;
  } catch {
    if (current === generation) error.value = t('ERROR');
  } finally {
    if (current === generation) loading.value = false;
  }
}
async function inspect(flow) {
  const current = ++generation;
  selected.value = flow;
  runs.value = [];
  loading.value = true;
  error.value = '';
  try {
    const result = await api.runs(flow.id);
    if (current === generation) runs.value = result.data;
  } catch {
    if (current === generation) error.value = t('ERROR');
  } finally {
    if (current === generation) loading.value = false;
  }
}
onMounted(load);
</script>

<template>
  <section class="flex-1 overflow-auto bg-n-background p-6 text-n-slate-12">
    <header class="mb-6 flex items-start justify-between gap-4">
      <div>
        <h1 class="mb-2 text-xl font-semibold">{{ t('TITLE') }}</h1>
        <p class="text-sm text-n-slate-11">{{ t('AGENT_HINT') }}</p>
      </div>
      <Button
        :label="t('REFRESH')"
        :disabled="loading"
        variant="faded"
        @click="load"
      />
    </header>
    <p v-if="error" role="alert" class="mb-4 text-n-ruby-11">{{ error }}</p>
    <p v-if="!loading && !flows.length" class="text-n-slate-11">
      {{ t('EMPTY') }}
    </p>
    <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
      <article
        v-for="flow in flows"
        :key="flow.id"
        class="rounded-xl border border-n-weak bg-n-solid-2 p-5"
      >
        <span class="text-xs text-n-blue-11">{{ t(flow.status) }}</span>
        <h2 class="my-3 text-base font-semibold">{{ flow.name }}</h2>
        <p class="mb-4 text-sm text-n-slate-11">
          {{
            inboxes
              .filter(inbox => flow.inbox_ids.includes(inbox.id))
              .map(inbox => inbox.name)
              .join(', ')
          }}
        </p>
        <Button
          :label="t('RUNS')"
          :disabled="loading"
          variant="faded"
          @click="inspect(flow)"
        />
      </article>
    </div>
    <section
      v-if="selected"
      class="mt-6 rounded-xl border border-n-weak bg-n-solid-2 p-5"
    >
      <h2 class="mb-4 text-base font-semibold">{{ selected.name }}</h2>
      <p v-if="!loading && !runs.length" class="text-sm text-n-slate-11">
        {{ t('NO_RUNS') }}
      </p>
      <ul class="space-y-3">
        <li
          v-for="run in runs"
          :key="run.id"
          class="flex flex-wrap items-center justify-between gap-3 border-b border-n-weak py-3 text-sm"
        >
          <span
            >{{ new Date(run.created_at).toLocaleString() }} ·
            {{ t(run.status) }}</span
          >
          <RouterLink
            class="text-n-blue-11"
            :to="
              '/app/accounts/' +
              accountId +
              '/conversations/' +
              run.conversation_id
            "
            >{{ t('CONVERSATION') }}</RouterLink
          >
        </li>
      </ul>
    </section>
  </section>
</template>
