<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';

defineProps({
  keepAlive: {
    type: Boolean,
    default: true,
  },
});

const route = useRoute();
const superAdminAccount = computed(
  () => window.globalConfig?.SUPER_ADMIN_ACCOUNT
);
const superAdminReturnUrl = computed(() =>
  superAdminAccount.value ? `/super_admin/accounts/${superAdminAccount.value.id}` : '/super_admin'
);
</script>

<template>
  <div
    class="flex flex-col w-full h-full m-0 pb-8 pt-4 px-6 overflow-auto bg-n-surface-1"
  >
    <div
      v-if="superAdminAccount"
      class="flex items-center justify-between w-full max-w-5xl mx-auto mb-4 rounded-lg border border-n-weak bg-n-alpha-2 px-4 py-3 text-sm text-n-slate-12"
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
    <div class="flex items-start w-full max-w-5xl mx-auto">
      <router-view v-slot="{ Component }">
        <keep-alive v-if="keepAlive">
          <component :is="Component" :key="route.fullPath" />
        </keep-alive>
        <component :is="Component" v-else :key="route.fullPath" />
      </router-view>
    </div>
  </div>
</template>
