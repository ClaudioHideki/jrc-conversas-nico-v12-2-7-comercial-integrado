<script setup>
import { onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import JrcCampaignsAPI from 'dashboard/api/jrcCampaigns';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();
const entries = ref([]);
const saving = ref(false);
const form = reactive({ phone_number: '', evidence: '' });
const load = async () => {
  try {
    const { data } = await JrcCampaignsAPI.consents();
    entries.value = data;
  } catch (error) {
    useAlert(
      error?.response?.data?.errors?.join(', ') ||
        t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED')
    );
  }
};
const add = async () => {
  saving.value = true;
  try {
    await JrcCampaignsAPI.createConsent(form);
    form.phone_number = '';
    form.evidence = '';
    await load();
  } catch (error) {
    useAlert(
      error?.response?.data?.errors?.join(', ') ||
        t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED')
    );
  } finally {
    saving.value = false;
  }
};
const revoke = async id => {
  try {
    await JrcCampaignsAPI.revokeConsent(id);
    await load();
  } catch (error) {
    useAlert(
      error?.response?.data?.errors?.join(', ') ||
        t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED')
    );
  }
};
onMounted(load);
</script>

<template>
  <section class="mt-8 space-y-4 rounded-xl border border-n-weak p-5">
    <h2 class="text-xl font-semibold text-n-slate-12">
      {{ t('JRC_CAMPAIGNS.GOVERNANCE.CONSENTS') }}
    </h2>
    <p class="text-sm text-n-slate-11">
      {{ t('JRC_CAMPAIGNS.GOVERNANCE.CONSENT_HELP') }}
    </p>
    <form class="flex flex-wrap gap-3" @submit.prevent="add">
      <input
        v-model="form.phone_number"
        required
        class="rounded-lg border border-n-weak bg-n-background px-3 py-2"
        :aria-label="t('JRC_CAMPAIGNS.BLACKLIST.PHONE')"
        :placeholder="t('JRC_CAMPAIGNS.BLACKLIST.PHONE')"
      />
      <input
        v-model="form.evidence"
        required
        class="min-w-64 flex-1 rounded-lg border border-n-weak bg-n-background px-3 py-2"
        :aria-label="t('JRC_CAMPAIGNS.GOVERNANCE.EVIDENCE')"
        :placeholder="t('JRC_CAMPAIGNS.GOVERNANCE.EVIDENCE')"
      />
      <button
        type="submit"
        class="rounded-lg bg-n-brand px-4 py-2 text-white disabled:opacity-40"
        :disabled="saving || !form.phone_number.trim() || !form.evidence.trim()"
      >
        {{ t('JRC_CAMPAIGNS.GOVERNANCE.RECORD_CONSENT') }}
      </button>
    </form>
    <div
      v-for="entry in entries"
      :key="entry.id"
      class="flex items-center justify-between gap-4 border-t border-n-weak py-3 text-sm text-n-slate-12"
    >
      <div>
        <p class="font-medium">{{ entry.phone_number }}</p>
        <p>{{ `${entry.evidence} · ${entry.granted_at}` }}</p>
      </div>
      <span v-if="entry.revoked_at">{{
        t('JRC_CAMPAIGNS.GOVERNANCE.REVOKED')
      }}</span>
      <button
        v-else
        type="button"
        class="rounded-lg px-3 py-2 text-n-ruby-11 hover:bg-n-ruby-3"
        @click="revoke(entry.id)"
      >
        {{ t('JRC_CAMPAIGNS.GOVERNANCE.REVOKE') }}
      </button>
    </div>
  </section>
</template>
