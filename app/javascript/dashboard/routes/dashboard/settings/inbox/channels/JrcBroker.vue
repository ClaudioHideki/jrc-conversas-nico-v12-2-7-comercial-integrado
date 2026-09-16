<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import AccountConfiguration from 'dashboard/components-next/jrc-broker/AccountConfiguration.vue';
import OnboardingFlow from 'dashboard/components-next/jrc-broker/OnboardingFlow.vue';

const { t } = useI18n();
const { accountId, currentAccount } = useAccount();
const configured = ref(false);
const enabled = computed(
  () =>
    window.chatwootConfig?.jrcBrokerEnabled === true &&
    currentAccount.value?.features?.jrc_broker
);
watch(accountId, () => {
  configured.value = false;
});
</script>

<template>
  <div class="p-6 flex flex-col gap-5 max-w-4xl w-full">
    <h2 class="text-xl font-semibold">{{ t('JRC_BROKER.TITLE') }}</h2>
    <p>{{ t('JRC_BROKER.DESCRIPTION') }}</p>
    <template v-if="enabled">
      <AccountConfiguration
        :key="accountId"
        :account-id="accountId"
        @configured="configured = true"
      />
      <OnboardingFlow
        v-if="configured"
        :key="accountId"
        :account-id="accountId"
      />
    </template>
    <p v-else>{{ t('JRC_BROKER.DISABLED') }}</p>
  </div>
</template>
