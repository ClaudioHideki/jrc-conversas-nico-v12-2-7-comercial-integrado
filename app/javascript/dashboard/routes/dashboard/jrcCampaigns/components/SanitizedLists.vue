<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import JrcCampaignsAPI from 'dashboard/api/jrcCampaigns';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  lists: { type: Array, default: () => [] },
});
const emit = defineEmits(['changed']);
const { t } = useI18n();

const name = ref('');
const inputText = ref('');
const saving = ref(false);
const result = ref(null);

const parsedEntries = computed(() => {
  const entries = inputText.value
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(Boolean)
    .map(line => {
      const parts = line.split(/[;,\t]/).map(value => value.trim());
      if (parts.length === 1) return { phone: parts[0] };
      return { name: parts[0], phone: parts[1] };
    });

  const first = entries[0];
  const headerName = first?.name?.toLowerCase();
  const headerPhone = first?.phone?.toLowerCase();
  if (
    ['nome', 'name'].includes(headerName) &&
    ['telefone', 'phone', 'phone_number', 'celular'].includes(headerPhone)
  ) {
    entries.shift();
  }
  return entries;
});

const loadCsv = event => {
  const file = event.target.files?.[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    inputText.value = String(reader.result || '');
    if (!name.value) name.value = file.name.replace(/\.csv$/i, '');
  };
  reader.readAsText(file);
};

const sanitize = async () => {
  if (!name.value.trim() || parsedEntries.value.length === 0) return;
  saving.value = true;
  try {
    const { data } = await JrcCampaignsAPI.createSanitizedList({
      name: name.value,
      entries: parsedEntries.value,
    });
    result.value = data;
    name.value = '';
    inputText.value = '';
    useAlert(t('JRC_CAMPAIGNS.ALERTS.SANITIZED'));
    emit('changed');
  } finally {
    saving.value = false;
  }
};

const removeList = async id => {
  await JrcCampaignsAPI.deleteSanitizedList(id);
  emit('changed');
};
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-xl font-semibold text-n-slate-12">{{ $t('JRC_CAMPAIGNS.SANITIZE.TITLE') }}</h2>
      <p class="mt-1 text-sm text-n-slate-10">{{ $t('JRC_CAMPAIGNS.SANITIZE.SUBTITLE') }}</p>
    </div>

    <div class="rounded-xl border border-n-weak p-5">
      <div class="grid gap-4 md:grid-cols-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('JRC_CAMPAIGNS.SANITIZE.NAME') }}
          <input v-model="name" class="mt-1 w-full rounded-lg border border-n-weak bg-n-background px-3 py-2" :placeholder="$t('JRC_CAMPAIGNS.SANITIZE.NAME_PLACEHOLDER')" />
        </label>
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('JRC_CAMPAIGNS.SANITIZE.CSV') }}
          <input type="file" accept=".csv,text/csv" class="mt-1 block w-full rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm" @change="loadCsv" />
        </label>
      </div>
      <label class="mt-4 block text-sm font-medium text-n-slate-12">
        {{ $t('JRC_CAMPAIGNS.SANITIZE.PASTE') }}
        <textarea v-model="inputText" rows="9" class="mt-1 w-full rounded-lg border border-n-weak bg-n-background px-3 py-2 font-mono text-xs"></textarea>
      </label>
      <div class="mt-4 flex justify-end">
        <button type="button" class="rounded-lg bg-n-brand px-4 py-2 text-sm font-medium text-white disabled:opacity-40" :disabled="saving || !name.trim() || !parsedEntries.length" @click="sanitize">
          {{ $t('JRC_CAMPAIGNS.SANITIZE.PROCESS') }}
        </button>
      </div>
    </div>

    <div v-if="result" class="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
      <div class="rounded-xl border border-n-weak p-4"><div class="text-xs text-n-slate-10">{{ $t('JRC_CAMPAIGNS.SANITIZE.TOTAL') }}</div><div class="mt-1 text-2xl font-semibold">{{ result.stats.total || 0 }}</div></div>
      <div class="rounded-xl border border-n-weak p-4"><div class="text-xs text-n-slate-10">{{ $t('JRC_CAMPAIGNS.SANITIZE.VALID') }}</div><div class="mt-1 text-2xl font-semibold text-n-teal-11">{{ result.stats.valid || 0 }}</div></div>
      <div class="rounded-xl border border-n-weak p-4"><div class="text-xs text-n-slate-10">{{ $t('JRC_CAMPAIGNS.SANITIZE.INVALID') }}</div><div class="mt-1 text-2xl font-semibold text-n-ruby-11">{{ result.stats.invalid || 0 }}</div></div>
      <div class="rounded-xl border border-n-weak p-4"><div class="text-xs text-n-slate-10">{{ $t('JRC_CAMPAIGNS.SANITIZE.DUPLICATE') }}</div><div class="mt-1 text-2xl font-semibold">{{ result.stats.duplicate || 0 }}</div></div>
      <div class="rounded-xl border border-n-weak p-4"><div class="text-xs text-n-slate-10">{{ $t('JRC_CAMPAIGNS.SANITIZE.BLACKLISTED') }}</div><div class="mt-1 text-2xl font-semibold">{{ result.stats.blacklisted || 0 }}</div></div>
    </div>

    <div>
      <h3 class="mb-3 font-semibold text-n-slate-12">{{ $t('JRC_CAMPAIGNS.SANITIZE.LISTS') }}</h3>
      <div v-if="!lists.length" class="rounded-xl border border-dashed border-n-weak p-8 text-center text-sm text-n-slate-10">{{ $t('JRC_CAMPAIGNS.SANITIZE.NO_LISTS') }}</div>
      <div v-else class="overflow-hidden rounded-xl border border-n-weak">
        <div v-for="list in lists" :key="list.id" class="flex items-center justify-between border-b border-n-weak p-4 last:border-b-0">
          <div>
            <div class="font-medium text-n-slate-12">{{ list.name }}</div>
            <div class="mt-1 text-xs text-n-slate-10">{{ list.stats?.valid || 0 }} / {{ list.stats?.total || 0 }}</div>
          </div>
          <button type="button" class="rounded-lg p-2 text-n-ruby-11 hover:bg-n-ruby-3" :title="$t('JRC_CAMPAIGNS.DELETE')" @click="removeList(list.id)"><span class="i-lucide-trash-2 size-4" /></button>
        </div>
      </div>
    </div>
  </div>
</template>
