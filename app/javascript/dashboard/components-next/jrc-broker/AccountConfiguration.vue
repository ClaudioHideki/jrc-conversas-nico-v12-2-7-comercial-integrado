<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { createJrcBrokerApi } from 'dashboard/api/jrcBroker';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({ accountId: { type: Number, required: true } });
const emit = defineEmits(['configured']);
const { t } = useI18n();
const configuration = ref(null);
const origin = ref('');
const organizationId = ref('');
const controlKey = ref('');
const editing = ref(false);
const busy = ref(false);
const error = ref(false);
const controller = new AbortController();
const api = createJrcBrokerApi(props.accountId);
let disposed = false;
const save = async () => {
  if (busy.value) return;
  busy.value = true;
  error.value = false;
  try {
    const result = await api.configure(
      {
        origin: origin.value,
        organizationId: organizationId.value,
        controlKey: controlKey.value,
      },
      controller.signal
    );
    if (disposed) return;
    configuration.value = result;
    editing.value = false;
    emit('configured');
  } catch {
    if (!disposed) error.value = true;
  } finally {
    controlKey.value = '';
    busy.value = false;
  }
};
onMounted(async () => {
  try {
    const value = await api.configuration(controller.signal);
    if (disposed) return;
    configuration.value = value;
    origin.value = value.origin || value.allowedOrigins[0] || '';
    organizationId.value = value.organizationId || '';
    editing.value = !value.configured;
    if (value.configured) emit('configured');
  } catch {
    if (!disposed) error.value = true;
  }
});
onBeforeUnmount(() => {
  disposed = true;
  controller.abort();
  controlKey.value = '';
});
</script>

<template>
  <section class="border border-n-weak rounded-xl p-5 flex flex-col gap-4">
    <p>{{ t('JRC_BROKER.CONFIG_HELP') }}</p>
    <p v-if="error" role="alert">{{ t('JRC_BROKER.ERROR.CONFIGURATION') }}</p>
    <p v-if="configuration?.configured">{{ t('JRC_BROKER.CONFIGURED') }}</p>
    <Button
      v-if="configuration?.configured && !editing"
      variant="outline"
      :label="t('JRC_BROKER.ROTATE')"
      @click="editing = true"
    />
    <form v-if="editing" class="flex flex-col gap-4" @submit.prevent="save">
      <label class="flex flex-col gap-2">
        <span>{{ t('JRC_BROKER.ORIGIN') }}</span>
        <select
          v-model="origin"
          required
          :disabled="busy || configuration?.configured"
        >
          <option
            v-for="value in configuration?.allowedOrigins || []"
            :key="value"
            :value="value"
          >
            {{ value }}
          </option>
        </select>
      </label>
      <label class="flex flex-col gap-2">
        <span>{{ t('JRC_BROKER.ORGANIZATION') }}</span>
        <input
          v-model.trim="organizationId"
          required
          :disabled="busy || configuration?.configured"
        />
      </label>
      <label class="flex flex-col gap-2">
        <span>{{ t('JRC_BROKER.KEY') }}</span>
        <input
          v-model="controlKey"
          type="password"
          autocomplete="new-password"
          required
          :disabled="busy"
        />
      </label>
      <Button type="submit" :disabled="busy" :label="t('JRC_BROKER.SAVE')" />
    </form>
  </section>
</template>
