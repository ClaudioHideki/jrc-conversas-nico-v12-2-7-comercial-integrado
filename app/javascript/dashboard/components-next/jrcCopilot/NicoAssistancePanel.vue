<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import nicoAPI from 'dashboard/api/jrcNico';

const props = defineProps({
  accountId: { type: [String, Number], required: true },
  conversationId: { type: [String, Number], required: true },
  canManage: { type: Boolean, default: false },
});
const emit = defineEmits(['authorized']);
const { t } = useI18n();
const payload = ref(null);
const busy = ref(false);
const error = ref(false);
const createLead = ref(true);
const bindErp = ref(false);
let controller;
const recommendation = computed(() => payload.value?.recommendation || {});
const pending = computed(() => recommendation.value.status === 'pending');
const isCommercial = computed(
  () => recommendation.value.agent_key === 'comercial'
);
const hasCnpj = computed(() => Boolean(recommendation.value.cnpj));
const agentName = computed(
  () =>
    payload.value?.agents?.find(
      item => item.key === recommendation.value.agent_key
    )?.name || recommendation.value.agent_key
);

const request = async action => {
  controller?.abort();
  controller = new AbortController();
  busy.value = true;
  error.value = false;
  try {
    let response;
    if (action === 'authorize') {
      response = await nicoAPI.authorize(
        props.accountId,
        props.conversationId,
        {
          agent_key: recommendation.value.agent_key,
          create_lead: isCommercial.value && createLead.value,
          bind_erp: props.canManage && hasCnpj.value && bindErp.value,
        },
        controller.signal
      );
      emit('authorized', response.data.run);
    } else if (action === 'dismiss')
      response = await nicoAPI.dismiss(
        props.accountId,
        props.conversationId,
        controller.signal
      );
    else
      response = await nicoAPI.assistance(
        props.accountId,
        props.conversationId,
        controller.signal
      );
    payload.value = response.data;
  } catch (requestError) {
    if (requestError.name !== 'CanceledError') error.value = true;
  } finally {
    busy.value = false;
  }
};
watch(
  () => [props.accountId, props.conversationId],
  () => request('load'),
  { immediate: true }
);
onBeforeUnmount(() => controller?.abort());
</script>

<template>
  <section
    v-if="pending"
    class="rounded-xl border border-violet-300 bg-violet-50 p-3 text-sm text-violet-950"
  >
    <strong>{{ t('JRC_NICO.ASSISTANCE.TITLE') }}</strong>
    <p class="mt-1">
      {{
        t('JRC_NICO.ASSISTANCE.DETECTED', {
          agent: agentName,
          confidence: recommendation.confidence,
        })
      }}
    </p>
    <p class="mt-1 text-xs">{{ recommendation.reason }}</p>
    <p v-if="hasCnpj" class="mt-1 text-xs">
      {{ t('JRC_NICO.ASSISTANCE.CNPJ', { cnpj: recommendation.cnpj }) }}
    </p>
    <label
      v-if="isCommercial && !payload.lead"
      class="mt-3 flex gap-2"
      ><input v-model="createLead" type="checkbox" :disabled="busy" /><span>{{
        t('JRC_NICO.ASSISTANCE.CREATE_LEAD')
      }}</span></label
    >
    <label
      v-if="canManage && hasCnpj"
      class="mt-2 flex gap-2"
      ><input v-model="bindErp" type="checkbox" :disabled="busy" /><span>{{
        t('JRC_NICO.ASSISTANCE.BIND_ERP')
      }}</span></label
    >
    <p v-if="error" role="alert" class="mt-2 text-n-ruby-11">
      {{ t('JRC_NICO.ERROR') }}
    </p>
    <div class="mt-3 flex flex-wrap gap-2">
      <button
        type="button"
        :disabled="busy"
        class="rounded-lg bg-violet-700 px-3 py-2 font-semibold text-white disabled:opacity-40"
        @click="request('authorize')"
      >
        {{ t('JRC_NICO.ASSISTANCE.AUTHORIZE') }}
      </button>
      <button
        type="button"
        :disabled="busy"
        class="rounded-lg border border-violet-300 px-3 py-2 disabled:opacity-40"
        @click="request('dismiss')"
      >
        {{ t('JRC_NICO.ASSISTANCE.DISMISS') }}
      </button>
    </div>
  </section>
</template>
