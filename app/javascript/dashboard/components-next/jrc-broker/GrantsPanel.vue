<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { createJrcBrokerApi } from 'dashboard/api/jrcBroker';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  accountId: { type: Number, required: true },
  inboxId: { type: Number, required: true },
});
const { t } = useI18n();
const members = ref([]);
const selected = ref([]);
const error = ref(false);
const busy = ref(false);
const loaded = ref(false);
const api = createJrcBrokerApi(props.accountId);
const controller = new AbortController();
let disposed = false;
const apply = value => {
  if (disposed) return;
  members.value = value.data;
  selected.value = value.data
    .filter(member => member.can_pair)
    .map(member => member.user_id);
  loaded.value = true;
};
const save = async () => {
  if (busy.value) return;
  busy.value = true;
  error.value = false;
  try {
    apply(
      await api.updateGrants(
        props.inboxId,
        [...selected.value],
        controller.signal
      )
    );
  } catch {
    if (!disposed) {
      error.value = true;
      loaded.value = false;
      members.value = [];
      selected.value = [];
    }
  } finally {
    if (!disposed) busy.value = false;
  }
};
onMounted(async () => {
  try {
    apply(await api.grants(props.inboxId, controller.signal));
  } catch {
    if (!disposed) error.value = true;
  }
});
onBeforeUnmount(() => {
  disposed = true;
  controller.abort();
  members.value = [];
  selected.value = [];
});
</script>

<template>
  <section class="flex flex-col gap-4 p-5 border border-n-weak rounded-xl">
    <h3 class="text-lg font-semibold">{{ t('JRC_BROKER.GRANTS') }}</h3>
    <p>{{ t('JRC_BROKER.GRANTS_HELP') }}</p>
    <p v-if="error" role="alert">{{ t('JRC_BROKER.ERROR.DENIED') }}</p>
    <form v-if="loaded" class="flex flex-col gap-3" @submit.prevent="save">
      <label
        v-for="member in members"
        :key="member.user_id"
        class="flex items-center gap-2"
      >
        <input
          v-model="selected"
          type="checkbox"
          :value="member.user_id"
          :disabled="busy"
        />
        <span>{{ member.name }}</span>
      </label>
      <Button
        type="submit"
        :disabled="busy"
        :label="t('JRC_BROKER.SAVE_GRANTS')"
      />
    </form>
  </section>
</template>
