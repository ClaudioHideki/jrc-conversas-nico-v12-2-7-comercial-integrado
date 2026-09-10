<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import PerformanceDashboard from './components/performance/PerformanceDashboard.vue';

const currentUser = useMapGetter('getCurrentUser');
const agentId = computed(() => currentUser.value.id);
</script>

<template>
  <PerformanceDashboard scope="agent" :agent-id="agentId" />
</template>
