<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import PerformanceDashboard from './components/performance/PerformanceDashboard.vue';

const route = useRoute();
const agentId = computed(() => Number(route.params.id));
</script>

<template>
  <PerformanceDashboard scope="agent" :agent-id="agentId" show-back-button />
</template>
