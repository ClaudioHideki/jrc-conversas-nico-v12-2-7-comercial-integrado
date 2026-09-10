<script setup>
import PerformanceDashboard from './components/performance/PerformanceDashboard.vue';

const TEXT = Object.freeze({
  specialized: 'Relatórios especializados',
  specializedDescription:
    'Os relatórios anteriores, filtros e exportações continuam disponíveis.',
});

const reportModules = [
  {
    label: 'Tempo real',
    description: 'Conversas abertas e disponibilidade atual da operação.',
    icon: 'i-lucide-activity',
    color: 'bg-n-ruby-3 text-n-ruby-11',
    route: 'operational_live_reports',
  },
  {
    label: 'Equipe / Agentes',
    description: 'Selecione um agente e acompanhe o desempenho individual.',
    icon: 'i-lucide-users',
    color: 'bg-n-teal-3 text-n-teal-11',
    route: 'agent_reports_index',
  },
  {
    label: 'Conversas',
    description: 'Volume, respostas e resoluções com todos os filtros.',
    icon: 'i-lucide-messages-square',
    color: 'bg-n-blue-3 text-n-blue-11',
    route: 'conversation_reports',
  },
  {
    label: 'Caixas de entrada',
    description: 'Comparativo dos canais e caixas configuradas.',
    icon: 'i-lucide-inbox',
    color: 'bg-n-cyan-3 text-n-cyan-11',
    route: 'inbox_reports_index',
  },
  {
    label: 'Times',
    description: 'Resultados agrupados por equipe de atendimento.',
    icon: 'i-lucide-users-round',
    color: 'bg-n-violet-3 text-n-violet-11',
    route: 'team_reports_index',
  },
  {
    label: 'Etiquetas',
    description: 'Demanda e desempenho por categoria.',
    icon: 'i-lucide-tags',
    color: 'bg-n-amber-3 text-n-amber-11',
    route: 'label_reports_index',
  },
  {
    label: 'CSAT',
    description: 'Avaliações e comentários dos clientes.',
    icon: 'i-lucide-star',
    color: 'bg-n-violet-3 text-n-violet-11',
    route: 'csat_reports',
  },
  {
    label: 'SLA',
    description: 'Políticas, metas e violações de atendimento.',
    icon: 'i-lucide-shield-check',
    color: 'bg-n-ruby-3 text-n-ruby-11',
    route: 'sla_reports',
  },
  {
    label: 'Robôs',
    description: 'Automação, resoluções e transferências.',
    icon: 'i-lucide-bot',
    color: 'bg-n-slate-3 text-n-slate-11',
    route: 'bot_reports',
  },
  {
    label: 'Telefonia',
    description: 'Histórico e indicadores reais das chamadas do ramal.',
    icon: 'i-lucide-phone-call',
    color: 'bg-n-teal-3 text-n-teal-11',
    route: 'ramal_index',
  },
];
</script>

<template>
  <PerformanceDashboard scope="account">
    <section
      class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm"
    >
      <div>
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ TEXT.specialized }}
        </h2>
        <p class="mt-1 text-xs text-n-slate-9">
          {{ TEXT.specializedDescription }}
        </p>
      </div>
      <div class="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <RouterLink
          v-for="module in reportModules"
          :key="module.route"
          :to="{ name: module.route }"
          class="group flex items-center gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4 transition hover:-translate-y-0.5 hover:border-n-blue-6 hover:shadow-sm"
        >
          <span
            class="grid size-11 shrink-0 place-items-center rounded-xl"
            :class="module.color"
          >
            <span class="size-5" :class="module.icon" />
          </span>
          <span class="min-w-0 flex-1">
            <strong class="block text-sm text-n-slate-12">
              {{ module.label }}
            </strong>
            <span class="mt-1 block text-xs leading-5 text-n-slate-9">
              {{ module.description }}
            </span>
          </span>
          <span
            class="i-lucide-chevron-right size-4 text-n-slate-8 transition group-hover:translate-x-0.5 group-hover:text-n-brand"
          />
        </RouterLink>
      </div>
    </section>
  </PerformanceDashboard>
</template>
