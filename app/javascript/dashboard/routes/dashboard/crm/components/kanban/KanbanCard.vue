<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import CrmValueDisplay from '../shared/CrmValueDisplay.vue';
import CrmBadge from '../shared/CrmBadge.vue';
import { formatCrmDateTime } from '../../utils/dateTime';

const props = defineProps({
  deal: { type: Object, required: true },
});

const router = useRouter();

const openDeal = () => {
  router.push({ name: 'crm_deals', query: { dealId: props.deal.id } });
};

const ownerInitials = computed(() => {
  if (!props.deal.owner?.name) return '?';
  return props.deal.owner.name.substring(0, 2).toUpperCase();
});
</script>

<template>
  <div
    class="mb-3 cursor-grab rounded-2xl border border-n-weak bg-n-solid-2 p-4 shadow-sm transition hover:-translate-y-0.5 hover:border-n-brand hover:shadow-md"
    @click="openDeal"
  >
    <div class="flex justify-between items-start mb-1">
      <h4
        class="font-semibold text-sm text-n-slate-12 line-clamp-2 leading-tight"
        :title="deal.title"
      >
        {{ deal.title }}
      </h4>
      <div
        v-if="deal.has_new_messages"
        class="ml-2 size-2 shrink-0 rounded-full bg-n-brand"
        title="Novas mensagens"
      />
    </div>

    <div
      v-if="deal.company?.name"
      class="text-xs text-n-slate-11 truncate mb-1"
      :title="deal.company.name"
    >
      <i class="i-lucide-building text-n-slate-10 mr-1" />{{
        deal.company.name
      }}
    </div>
    <div
      v-if="deal.contact?.name"
      class="text-xs text-n-slate-11 truncate mb-2"
      :title="deal.contact.name"
    >
      <i class="i-lucide-user text-n-slate-10 mr-1" />{{ deal.contact.name }}
    </div>

    <div class="flex flex-wrap gap-1 mb-2">
      <CrmBadge v-if="deal.score" color="blue" size="sm">
        {{ deal.score }}
      </CrmBadge>
      <CrmBadge
        v-if="deal.priority"
        :color="deal.priority === 'high' ? 'red' : 'gray'"
        size="sm"
      >
        {{ deal.priority }}
      </CrmBadge>
      <CrmBadge v-if="deal.source" color="green" size="sm">
        {{ deal.source }}
      </CrmBadge>
    </div>

    <div
      class="flex justify-between items-center mt-2 pt-2 border-t border-n-weak"
    >
      <CrmValueDisplay
        :cents="deal.value_cents"
        class="font-medium text-sm text-n-slate-12"
      />
      <div class="flex items-center gap-2">
        <div v-if="deal.overdue" class="text-n-ruby-11" title="Atrasado">
          <i class="i-lucide-alert-circle w-4 h-4" />
        </div>
        <div
          class="flex size-7 items-center justify-center rounded-full bg-n-blue-3 text-xs font-bold text-n-blue-11"
          :title="deal.owner?.name"
        >
          {{ ownerInitials }}
        </div>
      </div>
    </div>

    <div class="mt-2 text-[10px] text-n-slate-10 flex flex-col gap-0.5">
      <div v-if="deal.last_interaction_at" class="flex items-center gap-1">
        <i class="i-lucide-clock w-3 h-3" /> Última:
        {{ formatCrmDateTime(deal.last_interaction_at) }}
      </div>
      <div
        v-if="deal.next_activity"
        class="flex items-center gap-1"
        :class="[
          deal.next_activity.is_overdue ? 'text-n-ruby-11 font-medium' : '',
        ]"
      >
        <i class="i-lucide-calendar w-3 h-3" /> Próx:
        {{
          deal.next_activity.due_at_display ||
          formatCrmDateTime(deal.next_activity.due_at)
        }}
        -
        {{ deal.next_activity.title }}
      </div>
      <div v-else class="text-orange-500 flex items-center gap-1">
        <i class="i-lucide-alert-triangle w-3 h-3" /> Sem próxima atividade
      </div>
    </div>
  </div>
</template>
