<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import CrmBadge from './CrmBadge.vue';

const props = defineProps({
  value: {
    type: String,
    required: true,
  },
});

const { t } = useI18n();

const mappedColor = computed(() => {
  const statusColors = {
    open: 'blue',
    won: 'green',
    lost: 'red',
    cancelled: 'gray',
    new: 'blue',
    in_contact: 'yellow',
    qualified: 'purple',
    converted: 'green',
    discarded: 'red',
    unqualified: 'red',
    draft: 'gray',
    pending_approval: 'yellow',
    sent: 'purple',
    viewed: 'blue',
    accepted: 'green',
    rejected: 'red',
    canceled: 'gray',
    scheduled: 'blue',
    in_progress: 'yellow',
    completed: 'green',
    overdue: 'red',
  };
  return statusColors[props.value?.toLowerCase()] || 'gray';
});

const mappedLabel = computed(() => {
  const labels = {
    new: 'Novo',
    in_contact: 'Em contato',
    qualified: 'Qualificado',
    converted: 'Convertido',
    discarded: 'Descartado',
    unqualified: 'Descartado',
    draft: 'Rascunho',
    pending_approval: 'Aprovação interna',
    sent: 'Enviada',
    viewed: 'Visualizada',
    accepted: 'Aceita',
    rejected: 'Recusada',
    canceled: 'Cancelada',
    scheduled: 'Agendada',
    in_progress: 'Em andamento',
    completed: 'Concluída',
    overdue: 'Atrasada',
  };
  if (labels[props.value?.toLowerCase()])
    return labels[props.value.toLowerCase()];
  // Use translation if available, otherwise capitalize
  const translationKey = `CRM.STATUS.${props.value?.toUpperCase()}`;
  const translated = t(translationKey);
  if (translated !== translationKey) return translated;

  if (!props.value) return '';
  return props.value.charAt(0).toUpperCase() + props.value.slice(1);
});
</script>

<template>
  <CrmBadge :color="mappedColor">
    {{ mappedLabel }}
  </CrmBadge>
</template>
