<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SettingsHeader from './SettingsHeader.vue';
const props = defineProps({
  headerTitle: { type: String, default: '' },
  icon: { type: String, default: '' },
  keepAlive: { type: Boolean, default: true },
  showBackButton: { type: Boolean, default: false },
  backUrl: { type: [String, Object], default: '' },
});

const { t } = useI18n();
const superAdminAccount = computed(
  () => window.globalConfig?.SUPER_ADMIN_ACCOUNT
);
const superAdminReturnUrl = computed(() =>
  superAdminAccount.value ? `/super_admin/accounts/${superAdminAccount.value.id}` : '/super_admin'
);

const showSettingsHeader = computed(
  () => props.headerTitle || props.icon || props.showBackButton
);
</script>

<template>
  <div class="flex flex-col h-full m-0 bg-n-surface-1 w-full">
    <div
      v-if="superAdminAccount"
      class="max-w-7xl w-full mx-auto mt-4 px-6"
    >
      <div
        class="flex items-center justify-between rounded-lg border border-n-weak bg-n-alpha-2 px-4 py-3 text-sm text-n-slate-12"
      >
        <span>
          Cliente / Conta:
          <strong>{{ superAdminAccount.name }}</strong>
        </span>
        <a
          :href="superAdminReturnUrl"
          class="text-woot-600 hover:text-woot-700 font-medium"
        >
          Voltar ao Super Admin
        </a>
      </div>
    </div>
    <SettingsHeader
      v-if="showSettingsHeader"
      :icon="icon"
      :header-title="t(headerTitle)"
      :show-back-button="showBackButton"
      :back-url="backUrl"
      class="z-20 max-w-7xl w-full mx-auto"
    />

    <router-view v-slot="{ Component }" class="px-4 overflow-hidden">
      <component :is="Component" v-if="!keepAlive" :key="$route.fullPath" />
      <keep-alive v-else>
        <component :is="Component" :key="$route.fullPath" />
      </keep-alive>
    </router-view>
  </div>
</template>
