<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { onMounted, ref } from 'vue';
import { rankingAPI } from 'dashboard/api/crm';
import { useAlert } from 'dashboard/composables';
import { useCrmMetrics } from '../../composables/useCrmMetrics';

const { formatBRL } = useCrmMetrics();
const period = ref('this_month');
const loading = ref(true);
const ranking = ref([]);

const range = () => {
  const end = new Date();
  const start = new Date();
  if (period.value === 'last_month') {
    start.setMonth(start.getMonth() - 1, 1);
    end.setDate(0);
  } else if (period.value === 'this_year') {
    start.setMonth(0, 1);
  } else {
    start.setDate(1);
  }
  const format = date => date.toISOString().slice(0, 10);
  return {
    'period[start_date]': format(start),
    'period[end_date]': format(end),
  };
};

const load = async () => {
  loading.value = true;
  try {
    const { data } = await rankingAPI.list(range());
    ranking.value = data.ranking || [];
  } catch (error) {
    useAlert(
      error.response?.data?.error || 'Não foi possível carregar o ranking.'
    );
  } finally {
    loading.value = false;
  }
};

onMounted(load);
</script>

<template>
  <div class="h-full overflow-auto bg-n-surface-1 p-6">
    <header class="mb-6 flex items-center justify-between gap-4">
      <div>
        <p class="text-xs font-semibold uppercase text-n-brand">
          Desempenho real
        </p>
        <h2 class="text-2xl font-bold text-n-slate-12">Ranking de vendas</h2>
      </div>
      <select
        v-model="period"
        class="rounded-xl border border-n-weak bg-n-solid-2 px-3 py-2 text-sm font-semibold text-n-slate-12"
        @change="load"
      >
        <option value="this_month">Este mês</option>
        <option value="last_month">Mês passado</option>
        <option value="this_year">Este ano</option>
      </select>
    </header>
    <div
      class="overflow-hidden rounded-2xl border border-n-weak bg-n-solid-2 shadow-sm"
    >
      <div
        v-if="loading"
        class="flex min-h-60 items-center justify-center text-n-slate-11"
      >
        <i class="i-lucide-loader-circle mr-2 size-5 animate-spin" />Carregando
        dados reais…
      </div>
      <table v-else class="min-w-full divide-y divide-n-weak text-sm">
        <thead
          class="bg-n-alpha-2 text-left text-xs font-semibold uppercase text-n-slate-11"
        >
          <tr>
            <th class="px-6 py-3">Posição</th>
            <th class="px-6 py-3">Agente</th>
            <th class="px-6 py-3 text-right">Negócios ganhos</th>
            <th class="px-6 py-3 text-right">Receita</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak">
          <tr v-if="!ranking.length">
            <td colspan="4" class="px-6 py-14 text-center text-n-slate-11">
              Nenhum resultado no período.
            </td>
          </tr>
          <tr
            v-for="(entry, index) in ranking"
            :key="entry.user.id"
            class="hover:bg-n-alpha-2"
          >
            <td class="px-6 py-4">
              <span
                class="inline-flex size-8 items-center justify-center rounded-full bg-n-iris-3 font-bold text-n-iris-11"
                >{{ index + 1 }}</span
              >
            </td>
            <td class="px-6 py-4">
              <p class="font-semibold text-n-slate-12">{{ entry.user.name }}</p>
              <p class="text-xs text-n-slate-10">{{ entry.user.email }}</p>
            </td>
            <td class="px-6 py-4 text-right font-semibold text-n-slate-12">
              {{ entry.metrics.closed_won_count || 0 }}
            </td>
            <td class="px-6 py-4 text-right font-bold text-n-teal-11">
              {{
                formatBRL(
                  entry.metrics.won_revenue_cents ||
                    entry.metrics.revenue_cents ||
                    0
                )
              }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
