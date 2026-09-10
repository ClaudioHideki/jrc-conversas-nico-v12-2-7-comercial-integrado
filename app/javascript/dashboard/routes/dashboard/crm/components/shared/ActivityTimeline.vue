<template>
  <div class="activity-timeline py-4">
    <div
      v-if="!events || !events.length"
      class="text-sm text-n-slate-10 text-center py-4"
    >
      Nenhuma atividade registrada
    </div>

    <div v-else class="relative border-l border-n-weak ml-3">
      <div
        v-for="(event, index) in sortedEvents"
        :key="event.id || index"
        class="mb-6 ml-6"
      >
        <div
          class="absolute w-3 h-3 bg-n-blue-30 rounded-full -left-1.5 border border-white mt-1.5"
        ></div>
        <div class="text-xs text-n-slate-10 mb-1">
          {{ formatDate(event.created_at) }}
        </div>
        <div class="bg-n-solid-2 border border-n-weak rounded p-3 shadow-sm">
          <div class="font-medium text-sm text-n-slate-12">{{ event.title }}</div>
          <div v-if="event.description" class="text-sm text-n-slate-11 mt-1">
            {{ event.description }}
          </div>
          <div class="text-xs text-n-slate-10 mt-2">
            Por: {{ event.user?.name || 'Sistema' }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { formatCrmDateTime } from '../../utils/dateTime';

const props = defineProps({
  events: {
    type: Array,
    default: () => [],
  },
});

const sortedEvents = computed(() => {
  return [...props.events].sort(
    (a, b) => new Date(b.created_at) - new Date(a.created_at)
  );
});

const formatDate = dateString => {
  return formatCrmDateTime(dateString);
};
</script>

