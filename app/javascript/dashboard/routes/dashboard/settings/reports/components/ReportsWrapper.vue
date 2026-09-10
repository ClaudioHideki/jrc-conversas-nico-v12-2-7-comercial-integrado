<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();

const showBackButton = computed(
  () => route.name && route.name !== 'account_overview_reports'
);
</script>

<template>
  <div class="w-full overflow-auto bg-n-background px-4 sm:px-6">
    <div class="mx-auto max-w-7xl pb-12">
      <div v-if="showBackButton" class="pt-4">
        <RouterLink
          :to="{ name: 'account_overview_reports' }"
          class="inline-flex h-9 items-center gap-2 rounded-xl border border-n-weak bg-n-solid-1 px-3 text-sm font-semibold text-n-brand hover:border-n-blue-6"
        >
          <span class="i-lucide-arrow-left size-4" />
          Voltar
        </RouterLink>
      </div>

      <router-view />
    </div>
  </div>
</template>