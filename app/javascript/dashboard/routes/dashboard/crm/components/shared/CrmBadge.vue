<script setup>
import { computed } from 'vue';

const props = defineProps({
  color: {
    type: String,
    default: 'gray',
  },
});

const colorClasses = computed(() => {
  const map = {
    gray: 'bg-n-slate-3 text-n-slate-11',
    blue: 'bg-n-blue-3 text-n-blue-11',
    green: 'bg-n-teal-3 text-n-teal-11',
    red: 'bg-n-ruby-3 text-n-ruby-11',
    yellow: 'bg-n-amber-3 text-n-amber-11',
    purple: 'bg-n-iris-3 text-n-iris-11',
    orange: 'bg-n-orange-3 text-n-orange-11',
  };
  return map[props.color] || map.gray;
});
</script>

<template>
  <span
    class="inline-flex items-center justify-center rounded-full px-2.5 py-1 text-xs font-bold"
    :class="colorClasses"
  >
    <slot />
  </span>
</template>
