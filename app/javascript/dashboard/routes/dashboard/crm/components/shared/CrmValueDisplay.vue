<template>
  <span>{{ formattedValue }}</span>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  cents: {
    type: Number,
    default: 0,
  },
});

const formattedValue = computed(() => {
  if (props.cents === null || props.cents === undefined) return 'R$ 0,00';

  const formatter = new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    minimumFractionDigits: 2,
  });

  return formatter.format(props.cents / 100);
});
</script>
