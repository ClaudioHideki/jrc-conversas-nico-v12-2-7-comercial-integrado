<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { createJrcBrokerApi } from 'dashboard/api/jrcBroker';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ConnectionPanel from './ConnectionPanel.vue';

const props = defineProps({
  accountId: { type: Number, required: true },
  inbox: { type: Object, required: true },
});
const { t } = useI18n();
const store = useStore();
const dialog = ref(null);
const available = ref(false);
const health = ref(null);
const enabled = computed(
  () =>
    window.chatwootConfig?.jrcBrokerEnabled === true &&
    props.inbox.jrc_broker_bound === true
);
let generation = 0;
let controller;
const clear = () => {
  generation += 1;
  controller?.abort();
  dialog.value?.close();
  available.value = false;
  health.value = null;
};
watch(
  () => [props.accountId, props.inbox.id, enabled.value],
  async () => {
    clear();
    if (!enabled.value) return;
    controller = new AbortController();
    const current = generation;
    try {
      const result = await createJrcBrokerApi(props.accountId).status(
        props.inbox.id,
        controller.signal
      );
      if (current !== generation) return;
      health.value = result;
      available.value = result.allowedActions?.includes('status') === true;
    } catch {
      if (current === generation) available.value = false;
    }
  },
  { immediate: true }
);
const unsubscribe = store?.subscribe(mutation => {
  if (mutation.type === 'LOGOUT') clear();
});
onBeforeUnmount(() => {
  clear();
  unsubscribe?.();
});
</script>

<template>
  <div v-if="enabled && available">
    <Button
      variant="outline"
      icon="i-lucide-link"
      :label="t('JRC_BROKER.CONNECTION')"
      :title="t(`JRC_BROKER.STATUS.${health.instanceStatus}`)"
      @click="dialog?.open()"
    />
    <Dialog
      ref="dialog"
      :title="t('JRC_BROKER.TITLE')"
      :show-confirm-button="false"
      :cancel-button-label="t('JRC_BROKER.CLOSE')"
      width="xl"
      overflow-y-auto
    >
      <ConnectionPanel
        :key="`${accountId}:${inbox.id}`"
        :account-id="accountId"
        :inbox-id="inbox.id"
      />
    </Dialog>
  </div>
</template>
