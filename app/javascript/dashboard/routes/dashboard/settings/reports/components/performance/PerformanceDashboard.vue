<script setup>
import { computed, ref, watch } from 'vue';
import ReportsAPI from 'dashboard/api/reports';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import wootConstants from 'dashboard/constants/globals';
import {
  downloadCsvFile,
  generateFileName,
} from 'dashboard/helper/downloadHelper';
import OverviewReportFilters from '../OverviewReportFilters.vue';
import { formatTime } from '../../constants';

const props = defineProps({
  scope: {
    type: String,
    default: 'account',
  },
  agentId: {
    type: [Number, String],
    default: null,
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
});

const TEXT = Object.freeze({
  accountTitle: 'Desempenho da operação',
  agentTitle: 'Meu Desempenho',
  accountSubtitle:
    'Acompanhe os resultados da operação e as prioridades da equipe.',
  agentSubtitle: 'Acompanhe sua evolução e organize suas prioridades.',
  conversations: 'Conversas',
  myConversations: 'Minhas conversas',
  awaiting: 'Aguardando resposta',
  resolved: 'Resolvidas',
  sla: 'Dentro do SLA',
  firstResponse: 'Primeira resposta',
  csat: 'CSAT',
  evolution: 'Evolução',
  queue: 'Fila que precisa de atenção',
  goals: 'Metas e indicadores',
  highlights: 'Destaques do período',
  reviews: 'Avaliações',
  team: 'Desempenho da equipe',
  download: 'Baixar relatório',
  details: 'Relatórios detalhados',
  unavailable: 'Não disponível',
  noData: 'Ainda não há dados para o período selecionado.',
  noFeedback: 'Nenhum comentário de avaliação neste período.',
  noTargets:
    'Nenhuma meta formal foi configurada; exibimos somente os valores reais atuais.',
  loading: 'Carregando dados reais do desempenho...',
  error: 'Não foi possível carregar o desempenho. Tente novamente.',
  backToTeam: 'Voltar para equipe',
  breadcrumb: 'JRC Conversas',
  previousPeriod: 'vs. período anterior',
  evolutionDescription: 'Resoluções no período selecionado',
  chartAria: 'Evolução de resoluções',
  open: 'abertas',
  responses: 'respostas',
  teamDescription: 'Resultados reais dos agentes no período selecionado.',
  viewTeam: 'Ver toda a equipe',
});

const report = ref(null);
const loading = ref(false);
const error = ref(false);
const activeFilter = ref(null);

const isAgentView = computed(() => props.scope === 'agent');
const title = computed(() =>
  isAgentView.value ? TEXT.agentTitle : TEXT.accountTitle
);
const subtitle = computed(() =>
  isAgentView.value ? TEXT.agentSubtitle : TEXT.accountSubtitle
);
const agentGreeting = computed(() =>
  report.value?.subject?.name
    ? `Olá, ${report.value.subject.name}. ${subtitle.value}`
    : subtitle.value
);

const numberValue = value => Number(value || 0);
const formatCount = value => numberValue(value).toLocaleString('pt-BR');
const formatDuration = value => {
  const seconds = Math.round(numberValue(value));
  return seconds ? formatTime(seconds) : '--';
};
const formatPercentage = value =>
  value === null || value === undefined
    ? '--'
    : `${numberValue(value).toFixed(1)}%`;
const formatRating = value =>
  value === null || value === undefined
    ? '--'
    : numberValue(value).toFixed(1).replace('.', ',');

const variation = (current, previous) => {
  const currentValue = numberValue(current);
  const previousValue = numberValue(previous);
  if (!previousValue) return null;
  return Math.round(((currentValue - previousValue) / previousValue) * 100);
};
const durationVariation = (current, previous) => {
  const currentValue = numberValue(current);
  const previousValue = numberValue(previous);
  if (!previousValue) return null;
  return Math.round(((previousValue - currentValue) / previousValue) * 100);
};
const variationText = card =>
  `${card.variation >= 0 ? '↑' : '↓'} ${Math.abs(card.variation)}% ${TEXT.previousPeriod}`;
const reviewFooter = feedback =>
  `${feedback.contact_name} · ${feedback.rating}/5`;

const metricCards = computed(() => {
  const summary = report.value?.summary || {};
  const previous = summary.previous || {};
  const queue = report.value?.queue || {};
  const sla = report.value?.sla || {};
  const csat = report.value?.csat || {};

  return [
    {
      label: isAgentView.value ? TEXT.myConversations : TEXT.conversations,
      value: formatCount(summary.conversations_count),
      variation: variation(
        summary.conversations_count,
        previous.conversations_count
      ),
      icon: 'i-lucide-messages-square',
      color: 'bg-n-blue-3 text-n-blue-11',
    },
    {
      label: TEXT.awaiting,
      value: formatCount(queue.awaiting_reply),
      variation: null,
      icon: 'i-lucide-clock-3',
      color: 'bg-n-amber-3 text-n-amber-11',
    },
    {
      label: TEXT.resolved,
      value: formatCount(summary.resolutions_count),
      variation: variation(
        summary.resolutions_count,
        previous.resolutions_count
      ),
      icon: 'i-lucide-circle-check-big',
      color: 'bg-n-teal-3 text-n-teal-11',
    },
    {
      label: TEXT.sla,
      value: sla.available ? formatPercentage(sla.hit_rate) : '--',
      variation: null,
      icon: 'i-lucide-shield-check',
      color: 'bg-n-cyan-3 text-n-cyan-11',
    },
    {
      label: TEXT.firstResponse,
      value: formatDuration(summary.avg_first_response_time),
      variation: durationVariation(
        summary.avg_first_response_time,
        previous.avg_first_response_time
      ),
      icon: 'i-lucide-zap',
      color: 'bg-n-blue-3 text-n-blue-11',
    },
    {
      label: TEXT.csat,
      value: formatRating(csat.average),
      variation: null,
      icon: 'i-lucide-star',
      color: 'bg-n-violet-3 text-n-violet-11',
    },
  ];
});

const queueItems = computed(() => {
  const queue = report.value?.queue || {};
  const assigneeType = isAgentView.value
    ? wootConstants.ASSIGNEE_TYPE.ME
    : wootConstants.ASSIGNEE_TYPE.ALL;
  return [
    {
      value: queue.waiting_over_30_minutes,
      label: 'aguardando resposta há mais de 30 minutos',
      action: 'Responder',
      icon: 'i-lucide-timer',
      color: 'bg-n-ruby-3 text-n-ruby-11',
      route: {
        name: 'home',
        query: {
          status: wootConstants.STATUS_TYPE.OPEN,
          assignee_type: assigneeType,
          sort_by: wootConstants.SORT_BY_TYPE.WAITING_SINCE_ASC,
        },
      },
    },
    {
      value: queue.unattended,
      label: 'conversas ainda não atendidas',
      action: 'Revisar',
      icon: 'i-lucide-message-circle-warning',
      color: 'bg-n-amber-3 text-n-amber-11',
      route: {
        name: 'conversation_unattended',
        query: {
          status: wootConstants.STATUS_TYPE.OPEN,
          assignee_type: assigneeType,
          sort_by: wootConstants.SORT_BY_TYPE.CREATED_AT_ASC,
        },
      },
    },
    {
      value: queue.pending,
      label: 'conversas pendentes',
      action: 'Acompanhar',
      icon: 'i-lucide-refresh-cw',
      color: 'bg-n-violet-3 text-n-violet-11',
      route: {
        name: 'home',
        query: {
          status: wootConstants.STATUS_TYPE.PENDING,
          assignee_type: assigneeType,
          sort_by: wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC,
        },
      },
    },
  ];
});

const chartRows = computed(() =>
  [...(report.value?.series?.resolutions_count || [])].sort(
    (first, second) => first.timestamp - second.timestamp
  )
);
const chartPoints = computed(() => {
  if (!chartRows.value.length) return '';
  const maxValue = Math.max(
    ...chartRows.value.map(point => numberValue(point.value)),
    1
  );
  const width = 520;
  const divisor = Math.max(chartRows.value.length - 1, 1);
  return chartRows.value
    .map((point, index) => {
      const x = 40 + (index * width) / divisor;
      const y = 180 - (numberValue(point.value) / maxValue) * 130;
      return `${x},${y}`;
    })
    .join(' ');
});
const chartAreaPoints = computed(() =>
  chartPoints.value ? `40,180 ${chartPoints.value} 560,180` : ''
);
const chartLabels = computed(() => {
  if (!chartRows.value.length) return [];
  const indexes = [
    ...new Set([
      0,
      Math.floor((chartRows.value.length - 1) / 2),
      chartRows.value.length - 1,
    ]),
  ];
  return indexes.map(index => ({
    x: 40 + (index * 520) / Math.max(chartRows.value.length - 1, 1),
    label: new Intl.DateTimeFormat('pt-BR', {
      day: '2-digit',
      month: '2-digit',
    }).format(new Date(chartRows.value[index].timestamp * 1000)),
  }));
});

const highlights = computed(() => {
  const summary = report.value?.summary || {};
  const previous = summary.previous || {};
  const items = [];
  const resolvedDifference =
    numberValue(summary.resolutions_count) -
    numberValue(previous.resolutions_count);
  const responseDifference =
    numberValue(previous.avg_first_response_time) -
    numberValue(summary.avg_first_response_time);

  if (resolvedDifference) {
    items.push({
      icon:
        resolvedDifference > 0
          ? 'i-lucide-trending-up'
          : 'i-lucide-trending-down',
      color:
        resolvedDifference > 0
          ? 'bg-n-teal-3 text-n-teal-11'
          : 'bg-n-amber-3 text-n-amber-11',
      text: `${Math.abs(resolvedDifference)} ${resolvedDifference > 0 ? 'resoluções a mais' : 'resoluções a menos'} que no período anterior.`,
    });
  }
  if (responseDifference) {
    items.push({
      icon: responseDifference > 0 ? 'i-lucide-zap' : 'i-lucide-clock-alert',
      color:
        responseDifference > 0
          ? 'bg-n-blue-3 text-n-blue-11'
          : 'bg-n-ruby-3 text-n-ruby-11',
      text: `O tempo de primeira resposta ${responseDifference > 0 ? 'melhorou' : 'aumentou'} ${formatDuration(Math.abs(responseDifference))}.`,
    });
  }
  return items;
});

const goalRows = computed(() => [
  {
    label: TEXT.sla,
    value: report.value?.sla?.available
      ? formatPercentage(report.value.sla.hit_rate)
      : TEXT.unavailable,
  },
  { label: TEXT.csat, value: formatRating(report.value?.csat?.average) },
  {
    label: TEXT.resolved,
    value: formatCount(report.value?.summary?.resolutions_count),
  },
]);

const fetchPerformance = async () => {
  if (!activeFilter.value || (isAgentView.value && !props.agentId)) return;
  loading.value = true;
  error.value = false;
  try {
    const response = await ReportsAPI.getPerformance({
      ...activeFilter.value,
      scope: isAgentView.value ? undefined : 'account',
      agentId: isAgentView.value ? props.agentId : undefined,
      groupBy: 'day',
    });
    report.value = response.data;
  } catch {
    error.value = true;
  } finally {
    loading.value = false;
  }
};

const onFilterChange = filter => {
  activeFilter.value = filter;
  fetchPerformance();
};

const downloadPerformance = () => {
  if (!report.value || !activeFilter.value) return;
  const rows = metricCards.value.map(card => `"${card.label}","${card.value}"`);
  const content = ['Indicador,Valor', ...rows].join('\n');
  downloadCsvFile(
    generateFileName({
      type: isAgentView.value ? 'meu-desempenho' : 'desempenho-operacao',
      to: activeFilter.value.to,
      businessHours: activeFilter.value.businessHours,
    }),
    content
  );
};

watch(
  () => props.agentId,
  () => {
    report.value = null;
    fetchPerformance();
  }
);
</script>

<template>
  <div class="flex flex-col gap-5 pb-10 pt-6">
    <header
      class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between"
    >
      <div>
        <RouterLink
          v-if="showBackButton"
          :to="{ name: 'agent_reports_index' }"
          class="mb-3 inline-flex items-center gap-1 text-sm font-medium text-n-brand hover:underline"
        >
          <span class="i-lucide-arrow-left size-4" />
          {{ TEXT.backToTeam }}
        </RouterLink>
        <p
          class="text-xs font-semibold uppercase tracking-[0.16em] text-n-brand"
        >
          {{ `${TEXT.breadcrumb} / ${title}` }}
        </p>
        <div class="mt-2 flex flex-wrap items-center gap-3">
          <h1 class="text-3xl font-semibold tracking-tight text-n-slate-12">
            {{ title }}
          </h1>
          <span
            v-if="report?.subject?.availability"
            class="inline-flex items-center gap-2 rounded-xl border border-n-teal-5 bg-n-teal-3 px-3 py-1.5 text-xs font-semibold text-n-teal-11"
          >
            <span class="size-2 rounded-full bg-n-teal-9" />
            {{ report.subject.availability }}
          </span>
        </div>
        <p class="mt-1 text-sm text-n-slate-10">
          <template v-if="isAgentView && report?.subject?.name">
            {{ agentGreeting }}
          </template>
          <template v-else>{{ subtitle }}</template>
        </p>
      </div>
      <Button
        :label="TEXT.download"
        icon="i-lucide-download"
        color="blue"
        outline
        :disabled="!report"
        @click="downloadPerformance"
      />
    </header>

    <section
      class="rounded-2xl border border-n-weak bg-n-solid-1 p-4 shadow-sm"
    >
      <OverviewReportFilters
        :disabled="loading"
        @filter-change="onFilterChange"
      />
    </section>

    <div v-if="loading && !report" class="grid min-h-80 place-items-center">
      <div class="flex flex-col items-center gap-3 text-sm text-n-slate-10">
        <Spinner :size="32" />
        {{ TEXT.loading }}
      </div>
    </div>

    <div
      v-else-if="error && !report"
      class="rounded-2xl border border-n-ruby-5 bg-n-ruby-3 p-6 text-sm text-n-ruby-11"
    >
      {{ TEXT.error }}
    </div>

    <template v-else-if="report">
      <section class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <article
          v-for="card in metricCards"
          :key="card.label"
          class="rounded-2xl border border-n-weak bg-n-solid-1 p-4 shadow-sm"
        >
          <div class="flex items-center gap-3">
            <span
              class="grid size-11 shrink-0 place-items-center rounded-full"
              :class="card.color"
            >
              <span class="size-5" :class="card.icon" />
            </span>
            <div class="min-w-0">
              <strong class="block text-2xl font-semibold text-n-slate-12">{{
                card.value
              }}</strong>
              <span class="block truncate text-xs text-n-slate-10">{{
                card.label
              }}</span>
            </div>
          </div>
          <p
            v-if="card.variation !== null"
            class="mt-3 text-xs font-medium"
            :class="card.variation >= 0 ? 'text-n-teal-11' : 'text-n-ruby-11'"
          >
            {{ variationText(card) }}
          </p>
        </article>
      </section>

      <section
        class="grid gap-4 xl:grid-cols-[minmax(0,1.6fr)_minmax(340px,1fr)]"
      >
        <article
          class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm"
        >
          <div class="flex items-center justify-between gap-3">
            <div>
              <h2 class="text-lg font-semibold text-n-slate-12">
                {{ TEXT.evolution }}
              </h2>
              <p class="text-xs text-n-slate-10">
                {{ TEXT.evolutionDescription }}
              </p>
            </div>
            <span
              class="rounded-lg bg-n-blue-3 px-2.5 py-1 text-xs font-semibold text-n-blue-11"
            >
              {{ TEXT.resolved }}
            </span>
          </div>
          <div
            v-if="chartPoints"
            class="mt-4 overflow-hidden rounded-xl bg-n-alpha-1 p-2"
          >
            <svg
              viewBox="0 0 600 220"
              class="h-64 w-full"
              role="img"
              :aria-label="TEXT.chartAria"
            >
              <defs>
                <linearGradient
                  id="performanceArea"
                  x1="0"
                  x2="0"
                  y1="0"
                  y2="1"
                >
                  <stop offset="0%" stop-color="#1688f8" stop-opacity="0.3" />
                  <stop offset="100%" stop-color="#1688f8" stop-opacity="0" />
                </linearGradient>
              </defs>
              <line
                x1="40"
                x2="560"
                y1="180"
                y2="180"
                stroke="currentColor"
                class="text-n-weak"
              />
              <line
                x1="40"
                x2="560"
                y1="115"
                y2="115"
                stroke="currentColor"
                stroke-dasharray="4 6"
                class="text-n-weak"
              />
              <polygon :points="chartAreaPoints" fill="url(#performanceArea)" />
              <polyline
                :points="chartPoints"
                fill="none"
                stroke="#1688f8"
                stroke-width="4"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <g v-for="label in chartLabels" :key="label.label">
                <text
                  :x="label.x"
                  y="208"
                  text-anchor="middle"
                  fill="currentColor"
                  class="text-[11px] text-n-slate-9"
                >
                  {{ label.label }}
                </text>
              </g>
            </svg>
          </div>
          <p v-else class="grid h-64 place-items-center text-sm text-n-slate-9">
            {{ TEXT.noData }}
          </p>
        </article>

        <article
          class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm"
        >
          <div class="flex items-center justify-between gap-3">
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ TEXT.queue }}
            </h2>
            <span class="text-xs text-n-slate-9">
              {{ `${formatCount(report.queue.open)} ${TEXT.open}` }}
            </span>
          </div>
          <div class="mt-4 flex flex-col gap-3">
            <RouterLink
              v-for="item in queueItems"
              :key="item.label"
              :to="item.route"
              class="group flex items-center gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-3 transition hover:border-n-blue-6"
            >
              <span
                class="grid size-9 shrink-0 place-items-center rounded-full"
                :class="item.color"
              >
                <span class="size-4" :class="item.icon" />
              </span>
              <span class="min-w-0 flex-1 text-sm text-n-slate-11">
                <strong class="text-n-slate-12">{{
                  formatCount(item.value)
                }}</strong>
                {{ item.label }}
              </span>
              <span class="text-xs font-semibold text-n-brand">{{
                item.action
              }}</span>
              <span class="i-lucide-chevron-right size-4 text-n-brand" />
            </RouterLink>
          </div>
        </article>
      </section>

      <section class="grid gap-4 lg:grid-cols-3">
        <article
          class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm"
        >
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ TEXT.goals }}
          </h2>
          <div class="mt-4 divide-y divide-n-weak">
            <div
              v-for="goal in goalRows"
              :key="goal.label"
              class="flex items-center justify-between py-3 text-sm"
            >
              <span class="text-n-slate-10">{{ goal.label }}</span>
              <strong class="text-n-slate-12">{{ goal.value }}</strong>
            </div>
          </div>
          <p class="mt-3 text-xs leading-5 text-n-slate-9">
            {{ TEXT.noTargets }}
          </p>
        </article>

        <article
          class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm"
        >
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ TEXT.highlights }}
          </h2>
          <div v-if="highlights.length" class="mt-4 flex flex-col gap-3">
            <div
              v-for="item in highlights"
              :key="item.text"
              class="flex items-start gap-3 text-sm text-n-slate-11"
            >
              <span
                class="grid size-9 shrink-0 place-items-center rounded-full"
                :class="item.color"
              >
                <span class="size-4" :class="item.icon" />
              </span>
              <p class="pt-2">{{ item.text }}</p>
            </div>
          </div>
          <p v-else class="mt-6 text-sm text-n-slate-9">{{ TEXT.noData }}</p>
        </article>

        <article
          class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm"
        >
          <div class="flex items-center justify-between gap-3">
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ TEXT.reviews }}
            </h2>
            <div class="text-right">
              <strong class="block text-3xl text-n-slate-12">{{
                formatRating(report.csat.average)
              }}</strong>
              <span class="text-xs text-n-slate-9">
                {{ `${formatCount(report.csat.count)} ${TEXT.responses}` }}
              </span>
            </div>
          </div>
          <div
            v-if="report.csat.feedback.length"
            class="mt-4 flex flex-col gap-3"
          >
            <blockquote
              v-for="feedback in report.csat.feedback"
              :key="feedback.created_at"
              class="rounded-xl border border-n-weak bg-n-alpha-1 p-3 text-sm text-n-slate-11"
            >
              {{ `“${feedback.message}”` }}
              <footer class="mt-2 text-xs text-n-slate-9">
                {{ reviewFooter(feedback) }}
              </footer>
            </blockquote>
          </div>
          <p v-else class="mt-6 text-sm text-n-slate-9">
            {{ TEXT.noFeedback }}
          </p>
        </article>
      </section>

      <section
        v-if="!isAgentView"
        class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm"
      >
        <div class="flex items-center justify-between gap-4">
          <div>
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ TEXT.team }}
            </h2>
            <p class="text-xs text-n-slate-9">
              {{ TEXT.teamDescription }}
            </p>
          </div>
          <RouterLink
            :to="{ name: 'agent_reports_index' }"
            class="text-sm font-semibold text-n-brand hover:underline"
          >
            {{ TEXT.viewTeam }}
          </RouterLink>
        </div>
        <div class="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <RouterLink
            v-for="agent in report.team"
            :key="agent.id"
            :to="{ name: 'agent_reports_show', params: { id: agent.id } }"
            class="rounded-xl border border-n-weak bg-n-alpha-1 p-4 transition hover:border-n-blue-6 hover:shadow-sm"
          >
            <strong class="block truncate text-sm text-n-slate-12">{{
              agent.name
            }}</strong>
            <div class="mt-3 grid grid-cols-2 gap-2 text-xs text-n-slate-9">
              <span>
                <b class="block text-base text-n-slate-12">{{
                  formatCount(agent.conversations_count)
                }}</b>
                {{ TEXT.conversations }}
              </span>
              <span>
                <b class="block text-base text-n-teal-11">{{
                  formatCount(agent.resolved_conversations_count)
                }}</b>
                {{ TEXT.resolved }}
              </span>
            </div>
          </RouterLink>
        </div>
      </section>

      <slot />
    </template>
  </div>
</template>
