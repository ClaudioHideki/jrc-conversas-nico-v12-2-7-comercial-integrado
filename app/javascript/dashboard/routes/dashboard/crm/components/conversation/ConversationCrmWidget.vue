<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { useRouter } from 'vue-router';
import CrmStatusBadge from '../shared/CrmStatusBadge.vue';
import CrmValueDisplay from '../shared/CrmValueDisplay.vue';
import { formatCrmDateTime } from '../../utils/dateTime';

const props = defineProps({
  linkedDeal: {
    type: Object,
    default: null,
  },
  linkedLead: {
    type: Object,
    default: null,
  },
  convertingLead: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['createDeal', 'createActivity', 'convertToLead']);
const router = useRouter();

const openLead = () => {
  if (props.linkedLead?.id) {
    router.push({ name: 'crm_leads', query: { leadId: props.linkedLead.id } });
  }
};

const openDeal = () => {
  if (props.linkedDeal?.id) {
    router.push({ name: 'crm_deals', query: { dealId: props.linkedDeal.id } });
  }
};

const createDeal = () => {
  emit('createDeal');
};

const convertToLead = () => emit('convertToLead');

const createActivity = () => {
  emit('createActivity', props.linkedDeal?.id);
};
</script>

<template>
  <div class="flex flex-col gap-3 border-t border-n-weak bg-n-alpha-1 p-3">
    <div class="flex items-center justify-between">
      <h4 class="font-semibold text-sm text-n-slate-12 flex items-center gap-1">
        <i class="i-lucide-briefcase w-4 h-4" /> CRM
      </h4>
    </div>

    <div
      v-if="linkedDeal"
      class="rounded-xl border border-n-weak bg-n-solid-2 p-3 text-sm shadow-sm"
    >
      <div class="mb-2">
        <div
          class="text-[10px] font-bold text-n-slate-10 uppercase tracking-wider mb-0.5"
        >
          NEGÓCIO
        </div>
        <div class="font-medium text-n-slate-12 leading-tight">
          {{ linkedDeal.title }}
        </div>
      </div>

      <div class="grid grid-cols-2 gap-2 mb-2">
        <div>
          <div
            class="text-[10px] font-bold text-n-slate-10 uppercase tracking-wider mb-0.5"
          >
            ETAPA
          </div>
          <CrmStatusBadge :value="linkedDeal.stage?.name" />
        </div>
        <div>
          <div
            class="text-[10px] font-bold text-n-slate-10 uppercase tracking-wider mb-0.5"
          >
            VALOR
          </div>
          <CrmValueDisplay
            :cents="linkedDeal.value_cents"
            class="font-medium text-n-teal-11"
          />
        </div>
      </div>

      <div class="mb-2">
        <div
          class="text-[10px] font-bold text-n-slate-10 uppercase tracking-wider mb-0.5"
        >
          RESPONSÁVEL
        </div>
        <div class="flex items-center gap-1 text-n-slate-11">
          <i class="i-lucide-user w-3 h-3 text-n-slate-10" />
          <span>{{ linkedDeal.owner?.name || 'Não atribuído' }}</span>
        </div>
      </div>

      <div
        v-if="linkedDeal.next_activity"
        class="mt-3 p-2 bg-n-blue-3 rounded border border-n-blue-6"
      >
        <div
          class="text-[10px] font-bold text-n-blue-11 uppercase tracking-wider mb-0.5"
        >
          PRÓXIMA ATIVIDADE
        </div>
        <div class="flex items-center gap-1 text-n-blue-12 text-xs font-medium">
          <i class="i-lucide-calendar w-3 h-3" />
          <span>
            {{
              linkedDeal.next_activity.due_at_display ||
              formatCrmDateTime(linkedDeal.next_activity.due_at)
            }}
            -
            {{ linkedDeal.next_activity.title }}
          </span>
        </div>
      </div>
      <div
        v-else
        class="mt-3 p-2 bg-orange-50 rounded border border-orange-100"
      >
        <div
          class="flex items-center gap-1 text-orange-800 text-xs font-medium"
        >
          <i class="i-lucide-alert-triangle w-3 h-3" />
          <span>Sem próxima atividade</span>
        </div>
      </div>
    </div>

    <div
      v-else-if="linkedLead"
      class="rounded-xl border border-n-weak bg-n-solid-2 p-3 text-sm shadow-sm"
    >
      <div class="flex items-start justify-between gap-2">
        <div class="min-w-0">
          <div
            class="text-[10px] font-bold uppercase tracking-wider text-n-slate-9"
          >
            LEAD VINCULADO
          </div>
          <div class="truncate font-medium text-n-slate-12">
            {{ linkedLead.name }}
          </div>
        </div>
        <CrmStatusBadge :value="linkedLead.status" />
      </div>
      <div class="mt-3 grid grid-cols-2 gap-2 text-xs text-n-slate-10">
        <div>
          <p class="font-semibold uppercase tracking-wide">Origem</p>
          <p class="mt-0.5 text-n-slate-12">
            {{ linkedLead.source || 'Conversa' }}
          </p>
        </div>
        <div>
          <p class="font-semibold uppercase tracking-wide">Responsável</p>
          <p class="mt-0.5 truncate text-n-slate-12">
            {{ linkedLead.owner?.name || 'Não atribuído' }}
          </p>
        </div>
      </div>
    </div>

    <div
      v-else
      class="bg-n-solid-2 p-4 rounded border border-dashed border-n-weak text-center flex flex-col items-center justify-center"
    >
      <i class="i-lucide-link-2 w-6 h-6 text-n-slate-9 mb-1" />
      <span class="text-xs text-n-slate-10">
        Esta conversa ainda não faz parte do CRM
      </span>
    </div>

    <div class="flex gap-2 w-full mt-1">
      <button
        v-if="linkedDeal"
        class="flex-1 bg-n-solid-2 border border-n-weak hover:bg-n-alpha-2 text-n-slate-11 py-1.5 px-2 rounded text-xs font-medium flex items-center justify-center gap-1 transition-colors"
        @click="openDeal"
      >
        <i class="i-lucide-external-link w-3 h-3" /> Abrir negócio
      </button>
      <button
        v-else-if="linkedLead"
        class="flex-1 rounded-lg border border-n-weak bg-n-solid-2 px-2 py-2 text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2"
        @click="openLead"
      >
        <i class="i-lucide-external-link h-3 w-3" /> Abrir lead
      </button>
      <button
        v-else
        :disabled="convertingLead"
        class="flex-1 rounded-lg bg-n-brand px-2 py-2 text-xs font-medium text-white hover:opacity-90 disabled:opacity-50"
        @click="convertToLead"
      >
        <i class="i-lucide-user-plus h-3 w-3" />
        {{ convertingLead ? 'Criando lead…' : 'Transformar em lead' }}
      </button>
      <button
        v-if="!linkedDeal && !linkedLead"
        class="rounded-lg border border-n-weak bg-n-solid-2 px-2 py-2 text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2"
        @click="createDeal"
      >
        <i class="i-lucide-briefcase-business h-3 w-3" /> Negócio direto
      </button>

      <button
        v-if="linkedDeal"
        class="flex-1 bg-n-brand hover:bg-n-blue-11 text-white py-1.5 px-2 rounded text-xs font-medium flex items-center justify-center gap-1 transition-colors"
        @click="createActivity"
      >
        <i class="i-lucide-plus w-3 h-3" /> Atividade
      </button>
    </div>
  </div>
</template>


