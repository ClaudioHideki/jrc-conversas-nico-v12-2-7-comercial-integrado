<script setup>
/* global axios */
import { onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
const props = defineProps({
  accountId: { type: [String, Number], required: true },
  conversationId: { type: [String, Number], required: true },
});
const { t } = useI18n();
const emit = defineEmits(['changed']);
const settings = ref({
  mode: 'off',
  operator_company_id: '',
  requester_user_id: '',
});
const binding = ref(null);
const document = ref('');
const reviewed = ref(false);
const busy = ref(false);
const error = ref(false);
let generation = 0;
let abort;
const request = async (action = '') => {
  const version = ++generation;
  abort?.abort();
  abort = new AbortController();
  busy.value = true;
  error.value = false;
  const url = `/api/v1/accounts/${Number(props.accountId)}/jrc_nico/erp`;
  const config = {
    signal: abort.signal,
    params: { conversation_id: props.conversationId },
  };
  try {
    let response;
    if (action === 'save')
      response = await axios.patch(url, settings.value, config);
    else if (action)
      response = await axios.post(
        `${url}/${action}`,
        { cnpj: document.value },
        config
      );
    else response = await axios.get(url, config);
    if (version !== generation) return;
    settings.value = response.data.settings;
    binding.value = response.data.binding;
    reviewed.value = false;
    if (action) emit('changed');
  } catch {
    if (version === generation) error.value = true;
  } finally {
    if (version === generation) busy.value = false;
  }
};
watch(
  () => [props.accountId, props.conversationId],
  () => {
    settings.value = {
      mode: 'off',
      operator_company_id: '',
      requester_user_id: '',
    };
    binding.value = null;
    document.value = '';
    reviewed.value = false;
    request();
  },
  { immediate: true }
);
onBeforeUnmount(() => {
  generation += 1;
  abort?.abort();
});
</script>

<template>
  <details class="rounded-xl border border-n-weak p-3 text-sm">
    <summary class="cursor-pointer font-semibold">
      {{ t('JRC_NICO.ERP.TITLE') }}
    </summary>
    <div class="mt-3 flex flex-col gap-3">
      <p>{{ t('JRC_NICO.ERP.DESCRIPTION') }}</p>
      <label
        >{{ t('JRC_NICO.ERP.MODE') }}
        <select
          v-model="settings.mode"
          :disabled="busy"
          class="w-full rounded border border-n-weak bg-n-background p-2"
        >
          <option value="off">{{ t('JRC_NICO.ERP.OFF') }}</option>
          <option value="fixture">{{ t('JRC_NICO.ERP.FIXTURE') }}</option>
          <option value="live">{{ t('JRC_NICO.ERP.LIVE') }}</option>
        </select>
      </label>
      <label
        >{{ t('JRC_NICO.ERP.OPERATOR')
        }}<input
          v-model="settings.operator_company_id"
          :disabled="busy"
          maxlength="13"
          class="w-full rounded border border-n-weak bg-n-background p-2"
      /></label>
      <label
        >{{ t('JRC_NICO.ERP.REQUESTER')
        }}<input
          v-model="settings.requester_user_id"
          :disabled="busy"
          maxlength="13"
          class="w-full rounded border border-n-weak bg-n-background p-2"
      /></label>
      <button
        type="button"
        :disabled="busy"
        class="text-n-blue-11"
        @click="request('save')"
      >
        {{ t('JRC_NICO.ERP.SAVE') }}
      </button>
      <label
        >{{ t('JRC_NICO.ERP.CNPJ')
        }}<input
          v-model="document"
          :disabled="busy"
          maxlength="18"
          class="w-full rounded border border-n-weak bg-n-background p-2"
      /></label>
      <label class="flex gap-2"
        ><input v-model="reviewed" type="checkbox" :disabled="busy" />{{
          t('JRC_NICO.ERP.REVIEW')
        }}</label
      >
      <button
        type="button"
        :disabled="busy || !reviewed || settings.mode === 'off'"
        class="text-n-blue-11 disabled:opacity-40"
        @click="request('bind')"
      >
        {{ t('JRC_NICO.ERP.BIND') }}
      </button>
      <p v-if="binding">
        {{ binding.customer_name }} · {{ binding.cnpj }} · BEMTEVI
        {{ binding.bemtevi_customer_id }} · Help Desk
        {{ binding.helpdesk_company_id }} · {{ binding.mode }} ·
        {{
          binding.enabled ? t('JRC_NICO.ERP.ACTIVE') : t('JRC_NICO.ERP.REVOKED')
        }}
      </p>
      <button
        v-if="binding?.enabled"
        type="button"
        :disabled="busy"
        class="text-n-ruby-11"
        @click="request('revoke')"
      >
        {{ t('JRC_NICO.ERP.REVOKE') }}
      </button>
      <p v-if="error" role="alert" class="text-n-ruby-11">
        {{ t('JRC_NICO.ERP.ERROR') }}
      </p>
    </div>
  </details>
</template>
