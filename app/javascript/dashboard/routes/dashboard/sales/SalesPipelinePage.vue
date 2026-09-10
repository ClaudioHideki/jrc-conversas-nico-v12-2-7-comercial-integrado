<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import Draggable from 'vuedraggable';
import SalesAPI from 'dashboard/api/sales';
import SalesOpportunityCard from './SalesOpportunityCard.vue';
import SalesOpportunityDrawer from './SalesOpportunityDrawer.vue';
import SalesOpportunityForm from './SalesOpportunityForm.vue';
import SalesPipelineFilters from './SalesPipelineFilters.vue';
import { useAlert } from 'dashboard/composables';
import { useRoute } from 'vue-router';

const loading = ref(true);
const route = useRoute();
const pipeline = ref({ stages: [], loss_reasons: [] });
const opportunities = ref([]);
const summary = ref({});
const metadata = ref({ users: [], teams: [] });
const board = reactive({});
const showCreate = ref(false);
const quickCreateStageId = ref(null);
const selectedOpportunityId = ref(null);
const pendingLostMove = ref(null);
const lossReasonId = ref('');
const lossNotes = ref('');
const filters = reactive({
  q: '',
  owner_id: '',
  team_id: '',
  channel: '',
  stage_id: '',
  product: '',
  temperature: '',
  status: '',
  from: '',
  to: '',
});

const selectedPipelineId = ref('');

const channels = computed(() => [
  ...new Set(
    opportunities.value.map(item => item.source_channel).filter(Boolean)
  ),
]);

const summaryCards = computed(() => [
  {
    key: 'open_count',
    label: 'SALES.SUMMARY.OPEN',
    icon: 'i-lucide-briefcase-business',
  },
  {
    key: 'open_value',
    label: 'SALES.SUMMARY.VALUE',
    icon: 'i-lucide-circle-dollar-sign',
    currency: true,
  },
  { key: 'won_count', label: 'SALES.SUMMARY.WON', icon: 'i-lucide-trophy' },
  { key: 'lost_count', label: 'SALES.SUMMARY.LOST', icon: 'i-lucide-circle-x' },
  {
    key: 'overdue_activities_count',
    label: 'SALES.SUMMARY.OVERDUE',
    icon: 'i-lucide-clock-alert',
  },
]);

const rebuildBoard = () => {
  pipeline.value.stages.forEach(stage => {
    board[stage.id] = opportunities.value.filter(
      opportunity => Number(opportunity.stage.id) === Number(stage.id)
    );
  });
};

const formatCurrency = value =>
  new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'BRL',
  }).format(Number(value || 0));

const stageValue = stageId =>
  (board[stageId] || []).reduce(
    (total, opportunity) => total + Number(opportunity.value || 0),
    0
  );

const load = async () => {
  loading.value = true;
  try {
    const [
      pipelineResponse,
      opportunitiesResponse,
      summaryResponse,
      metadataResponse,
    ] = await Promise.all([
      SalesAPI.pipeline(),
      SalesAPI.opportunities(filters),
      SalesAPI.summary(),
      SalesAPI.metadata(),
    ]);
    pipeline.value = pipelineResponse.data;
    selectedPipelineId.value = pipeline.value.id;
    opportunities.value = opportunitiesResponse.data.opportunities;
    summary.value = summaryResponse.data;
    metadata.value = metadataResponse.data;
    rebuildBoard();
  } catch (error) {
    useAlert(
      error.response?.data?.error || 'Não foi possível carregar o pipeline.'
    );
  } finally {
    loading.value = false;
  }
};

const move = async (opportunity, stage, extra = {}) => {
  try {
    await SalesAPI.moveOpportunity(opportunity.id, {
      stage_id: stage.id,
      ...extra,
    });
    await load();
  } catch (error) {
    useAlert(
      error.response?.data?.message || 'Não foi possível mover a oportunidade.'
    );
    await load();
  }
};

const handleStageChange = (event, stage) => {
  const opportunity = event.added?.element;
  if (!opportunity) return;
  if (stage.stage_type === 'lost') {
    pendingLostMove.value = { opportunity, stage };
    return;
  }
  move(opportunity, stage);
};

const confirmLostMove = async () => {
  if (!lossReasonId.value) return;
  await move(pendingLostMove.value.opportunity, pendingLostMove.value.stage, {
    loss_reason_id: lossReasonId.value,
    loss_notes: lossNotes.value,
  });
  pendingLostMove.value = null;
  lossReasonId.value = '';
  lossNotes.value = '';
};

const cancelLostMove = () => {
  pendingLostMove.value = null;
  lossReasonId.value = '';
  lossNotes.value = '';
  load();
};

const clearFilters = () => {
  Object.keys(filters).forEach(key => {
    filters[key] = '';
  });
  load();
};

const applyFilters = values => {
  Object.assign(filters, values);
  load();
};

const opportunitySaved = data => {
  showCreate.value = false;
  quickCreateStageId.value = null;
  selectedOpportunityId.value = data.id;
  load();
};

const openCreate = (stageId = null) => {
  quickCreateStageId.value = stageId;
  showCreate.value = true;
};

const formatSummary = item => {
  const value = summary.value[item.key] || 0;
  if (!item.currency) return value;
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'BRL',
  }).format(Number(value));
};

onMounted(() => {
  if (route.query.opportunityId) {
    selectedOpportunityId.value = Number(route.query.opportunityId);
  }
  load();
});
</script>

<template>
  <div
    class="flex h-full min-w-0 flex-1 flex-col overflow-hidden bg-n-surface-1"
  >
    <header class="shrink-0 border-b border-n-weak px-4 py-4 lg:px-6">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap items-center gap-3">
          <div>
            <h1 class="text-xl font-semibold text-n-slate-12">
              {{ $t('SALES.TITLE') }}
            </h1>
            <p class="text-sm text-n-slate-10">{{ $t('SALES.SUBTITLE') }}</p>
          </div>
          <label class="text-xs text-n-slate-10">
            {{ $t('SALES.PIPELINE') }}
            <select
              v-model="selectedPipelineId"
              class="ml-2 h-9 rounded-lg border border-n-weak bg-n-solid-2 px-3 text-sm text-n-slate-12"
              @change="load"
            >
              <option :value="pipeline.id">{{ pipeline.name }}</option>
            </select>
          </label>
        </div>
        <button
          type="button"
          class="flex items-center gap-2 rounded-lg bg-n-brand px-4 py-2 text-sm font-medium text-white"
          @click="openCreate()"
        >
          <span class="i-lucide-plus size-4" />{{ $t('SALES.NEW_OPPORTUNITY') }}
        </button>
      </div>
      <form class="mt-4 flex max-w-2xl gap-2" @submit.prevent="load">
        <label class="relative min-w-0 flex-1">
          <span
            class="i-lucide-search absolute left-3 top-1/2 size-4 -translate-y-1/2 text-n-slate-9"
          />
          <input
            v-model="filters.q"
            type="search"
            class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-2 pl-9 pr-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            :placeholder="$t('SALES.SEARCH_PLACEHOLDER')"
          />
        </label>
        <button
          type="submit"
          class="h-10 rounded-lg border border-n-weak px-4 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2"
        >
          {{ $t('SALES.SEARCH') }}
        </button>
      </form>
      <div class="mt-4 grid grid-cols-2 gap-2 md:grid-cols-5">
        <div
          v-for="item in summaryCards"
          :key="item.key"
          class="rounded-xl border border-n-weak bg-n-solid-2 p-3"
        >
          <div class="flex items-center gap-2 text-xs text-n-slate-10">
            <span :class="item.icon" class="size-4" />{{ $t(item.label) }}
          </div>
          <p class="mt-1 text-lg font-semibold text-n-slate-12">
            {{ formatSummary(item) }}
          </p>
        </div>
      </div>
      <SalesPipelineFilters
        class="mt-4"
        :filters="filters"
        :metadata="metadata"
        :stages="pipeline.stages"
        :channels="channels"
        @apply="applyFilters"
        @clear="clearFilters"
      />
    </header>
    <div
      v-if="loading"
      class="flex flex-1 items-center justify-center text-n-slate-11"
    >
      {{ $t('SALES.LOADING') }}
    </div>
    <div v-else class="flex flex-1 gap-4 overflow-x-auto p-4 lg:p-6">
      <section
        v-for="stage in pipeline.stages"
        :key="stage.id"
        class="flex w-72 min-w-72 flex-col rounded-xl bg-n-alpha-2"
      >
        <header class="flex items-start justify-between gap-2 px-3 py-3">
          <div class="flex items-center gap-2">
            <span
              class="size-2.5 rounded-full"
              :style="{ backgroundColor: stage.color }"
            />
            <h2 class="text-sm font-semibold text-n-slate-12">
              {{ stage.name }}
            </h2>
          </div>
          <div class="text-right">
            <span
              class="rounded-full bg-n-solid-2 px-2 py-0.5 text-xs text-n-slate-10"
              >{{ board[stage.id]?.length || 0 }}</span
            >
            <p class="mt-1 text-xs font-medium text-n-slate-11">
              {{ formatCurrency(stageValue(stage.id)) }}
            </p>
          </div>
        </header>
        <Draggable
          v-model="board[stage.id]"
          item-key="id"
          group="sales-opportunities"
          animation="180"
          ghost-class="opacity-40"
          class="flex min-h-32 flex-1 flex-col gap-2 overflow-y-auto px-2 pb-3"
          @change="event => handleStageChange(event, stage)"
        >
          <template #item="{ element }">
            <SalesOpportunityCard
              :opportunity="element"
              @open="selectedOpportunityId = element.id"
            />
          </template>
          <template #footer>
            <div
              v-if="!board[stage.id]?.length"
              class="rounded-lg border border-dashed border-n-weak p-4 text-center text-xs text-n-slate-10"
            >
              {{ $t('SALES.EMPTY_STAGE') }}
            </div>
            <button
              v-if="stage.stage_type !== 'lost'"
              type="button"
              class="mt-2 flex w-full items-center justify-center gap-1 rounded-lg border border-dashed border-n-weak px-3 py-2 text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2"
              @click="openCreate(stage.id)"
            >
              <span class="i-lucide-plus size-4" />
              {{ $t('SALES.QUICK_ADD') }}
            </button>
          </template>
        </Draggable>
      </section>
    </div>
    <SalesOpportunityForm
      v-if="showCreate"
      :target-stage-id="quickCreateStageId"
      @close="
        showCreate = false;
        quickCreateStageId = null;
      "
      @saved="opportunitySaved"
    />
    <SalesOpportunityDrawer
      :opportunity-id="selectedOpportunityId"
      :stages="pipeline.stages"
      :loss-reasons="pipeline.loss_reasons"
      @close="selectedOpportunityId = null"
      @changed="load"
    />
    <Teleport to="body">
      <div
        v-if="pendingLostMove"
        class="fixed inset-0 z-[80] flex items-center justify-center bg-black/40 p-4"
      >
        <div class="w-full max-w-md rounded-xl bg-n-solid-2 p-6 shadow-2xl">
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ $t('SALES.MARK_LOST') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-10">
            {{ pendingLostMove.opportunity.title }}
          </p>
          <label class="mt-4 block text-sm text-n-slate-11"
            >{{ $t('SALES.LOSS_REASON')
            }}<select
              v-model="lossReasonId"
              class="mt-1 w-full rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2"
            >
              <option disabled value="">
                {{ $t('SALES.SELECT_LOSS_REASON') }}
              </option>
              <option
                v-for="reason in pipeline.loss_reasons"
                :key="reason.id"
                :value="reason.id"
              >
                {{ reason.name }}
              </option>
            </select></label
          ><label class="mt-3 block text-sm text-n-slate-11"
            >{{ $t('SALES.LOSS_NOTES')
            }}<textarea
              v-model="lossNotes"
              rows="3"
              class="mt-1 w-full rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2"
            />
          </label>
          <div class="mt-5 flex justify-end gap-2">
            <button
              type="button"
              class="rounded-lg px-4 py-2 text-sm text-n-slate-11"
              @click="cancelLostMove"
            >
              {{ $t('SALES.CANCEL') }}</button
            ><button
              type="button"
              :disabled="!lossReasonId"
              class="rounded-lg bg-n-ruby-9 px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
              @click="confirmLostMove"
            >
              {{ $t('SALES.CONFIRM_LOST') }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
