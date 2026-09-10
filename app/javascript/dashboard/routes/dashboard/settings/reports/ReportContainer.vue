<script>
import { mapGetters } from 'vuex';
import { useReportMetrics } from 'dashboard/composables/useReportMetrics';
import { GROUP_BY_FILTER, METRIC_CHART } from './constants';
import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';
import { formatTime } from '@chatwoot/utils';
import { useAlert } from 'dashboard/composables';
import ChartStats from './components/ChartElements/ChartStats.vue';
import BarChart from 'shared/components/charts/BarChart.vue';
import ReportDrilldownDrawer from './components/ReportDrilldownDrawer.vue';

export default {
  components: { ChartStats, BarChart, ReportDrilldownDrawer },
  props: {
    groupBy: {
      type: Object,
      default: () => ({}),
    },
    from: {
      type: Number,
      default: 0,
    },
    to: {
      type: Number,
      default: 0,
    },
    reportType: {
      type: String,
      default: 'account',
    },
    selectedItemId: {
      type: [String, Number],
      default: null,
    },
    businessHours: {
      type: Boolean,
      default: false,
    },
    accountSummaryKey: {
      type: String,
      default: 'getAccountSummary',
    },
    summaryFetchingKey: {
      type: String,
      default: 'getAccountSummaryFetchingStatus',
    },
    reportKeys: {
      type: Object,
      default: () => ({
        CONVERSATIONS: 'conversations_count',
        INCOMING_MESSAGES: 'incoming_messages_count',
        OUTGOING_MESSAGES: 'outgoing_messages_count',
        FIRST_RESPONSE_TIME: 'avg_first_response_time',
        RESOLUTION_TIME: 'avg_resolution_time',
        RESOLUTION_COUNT: 'resolutions_count',
        REPLY_TIME: 'reply_time',
      }),
    },
  },
  setup(props) {
    const { calculateTrend, isAverageMetricType } = useReportMetrics(
      props.accountSummaryKey
    );
    return { calculateTrend, isAverageMetricType };
  },
  data() {
    return {
      drilldownRequest: null,
      drilldownMetric: null,
      drilldownIndex: null,
    };
  },
  computed: {
    ...mapGetters({
      accountReport: 'getAccountReports',
      currentRole: 'getCurrentRole',
    }),
    isAdmin() {
      return this.currentRole === 'administrator';
    },
    canDrilldownPrev() {
      return this.findDrillableIndex(this.drilldownIndex - 1, -1) !== null;
    },
    canDrilldownNext() {
      return this.findDrillableIndex(this.drilldownIndex + 1, 1) !== null;
    },
    metrics() {
      const reportKeys = Object.keys(this.reportKeys);
      const infoText = {
        FIRST_RESPONSE_TIME: this.$t(
          `REPORT.METRICS.FIRST_RESPONSE_TIME.INFO_TEXT`
        ),
        RESOLUTION_TIME: this.$t(`REPORT.METRICS.RESOLUTION_TIME.INFO_TEXT`),
      };
      return reportKeys.map(key => ({
        NAME: this.$t(`REPORT.METRICS.${key}.NAME`),
        KEY: this.reportKeys[key],
        DESC: this.$t(`REPORT.METRICS.${key}.DESC`),
        INFO_TEXT: infoText[key],
        TOOLTIP_TEXT: `REPORT.METRICS.${key}.TOOLTIP_TEXT`,
        trend: this.calculateTrend(this.reportKeys[key]),
      }));
    },
  },
  methods: {
    metricTheme(key) {
      const themes = {
        conversations_count: {
          icon: 'i-lucide-messages-square',
          tone: 'bg-n-blue-3 text-n-blue-11',
        },
        incoming_messages_count: {
          icon: 'i-lucide-inbox',
          tone: 'bg-n-cyan-3 text-n-cyan-11',
        },
        outgoing_messages_count: {
          icon: 'i-lucide-send',
          tone: 'bg-n-teal-3 text-n-teal-11',
        },
        avg_first_response_time: {
          icon: 'i-lucide-zap',
          tone: 'bg-n-amber-3 text-n-amber-11',
        },
        avg_resolution_time: {
          icon: 'i-lucide-circle-check-big',
          tone: 'bg-n-violet-3 text-n-violet-11',
        },
        resolutions_count: {
          icon: 'i-lucide-check-check',
          tone: 'bg-n-teal-3 text-n-teal-11',
        },
        reply_time: {
          icon: 'i-lucide-hourglass',
          tone: 'bg-n-slate-3 text-n-slate-11',
        },
      };
      return themes[key] || themes.conversations_count;
    },
    getCollection(metric) {
      if (!this.accountReport.data[metric.KEY]) {
        return {};
      }
      const data = this.accountReport.data[metric.KEY];
      const labels = data.map(element => {
        if (this.groupBy?.period === GROUP_BY_FILTER[2].period) {
          let week_date = new Date(fromUnixTime(element.timestamp));
          const first_day = week_date.getDate() - week_date.getDay();
          const last_day = first_day + 6;
          const week_first_date = new Date(week_date.setDate(first_day));
          const week_last_date = new Date(week_date.setDate(last_day));
          return `${format(week_first_date, 'dd-MMM')} - ${format(
            week_last_date,
            'dd-MMM'
          )}`;
        }
        if (this.groupBy?.period === GROUP_BY_FILTER[3].period) {
          return format(fromUnixTime(element.timestamp), 'MMM-yyyy');
        }
        if (this.groupBy?.period === GROUP_BY_FILTER[4].period) {
          return format(fromUnixTime(element.timestamp), 'yyyy');
        }
        return format(fromUnixTime(element.timestamp), 'dd-MMM');
      });
      const datasets = METRIC_CHART[metric.KEY].datasets.map(dataset => {
        switch (dataset.type) {
          case 'bar':
            return {
              ...dataset,
              yAxisID: 'y',
              label: metric.NAME,
              data: data.map(element => element.value),
            };
          case 'line':
            return {
              ...dataset,
              yAxisID: 'y',
              label: this.metrics[0].NAME,
              data: data.map(element => element.count),
            };
          default:
            return dataset;
        }
      });
      return {
        labels,
        datasets,
      };
    },
    getChartOptions(metric) {
      const options = {
        scales: METRIC_CHART[metric.KEY].scales,
      };

      // Only add tooltip configuration for time-based metrics
      if (this.isAverageMetricType(metric.KEY)) {
        options.plugins = {
          tooltip: {
            callbacks: {
              label: ({ raw, dataIndex }) => {
                return this.$t(metric.TOOLTIP_TEXT, {
                  metricValue: formatTime(raw || 0),
                  conversationCount:
                    this.accountReport.data[metric.KEY][dataIndex]?.count || 0,
                });
              },
            },
          },
        };
      }

      return options;
    },
    isDrilldownEnabled() {
      return !!(this.from && this.to);
    },
    onChartElementClick(metric, event) {
      if (!this.isDrilldownEnabled()) return;

      const dataPoint = this.accountReport.data[metric.KEY]?.[event.dataIndex];
      if (!this.canOpenDrilldown(metric, dataPoint)) return;
      if (!this.isAdmin) {
        useAlert(this.$t('REPORT.DRILLDOWN.ADMIN_ONLY'));
        return;
      }

      this.openDrilldownAt(metric, event.dataIndex);
    },
    openDrilldownAt(metric, dataIndex) {
      const dataPoint = this.accountReport.data[metric.KEY]?.[dataIndex];
      if (!this.canOpenDrilldown(metric, dataPoint)) return;

      const labels = this.getCollection(metric).labels || [];

      this.drilldownMetric = metric;
      this.drilldownIndex = dataIndex;
      this.drilldownRequest = {
        metric: metric.KEY,
        metricName: metric.NAME,
        bucketLabel: labels[dataIndex],
        bucketTimestamp: dataPoint.timestamp,
        bucketValue: dataPoint.value,
        isAverageMetric: this.isAverageMetricType(metric.KEY),
        from: this.from,
        to: this.to,
        type: this.reportType,
        id: this.selectedItemId,
        groupBy: this.groupBy?.period,
        businessHours: this.businessHours,
      };
    },
    navigateDrilldown(direction) {
      const nextIndex = this.findDrillableIndex(
        this.drilldownIndex + direction,
        direction
      );
      if (nextIndex === null) return;

      this.openDrilldownAt(this.drilldownMetric, nextIndex);
    },
    findDrillableIndex(startIndex, step) {
      if (!this.drilldownMetric) return null;

      const data = this.accountReport.data[this.drilldownMetric.KEY] || [];
      for (
        let index = startIndex;
        index >= 0 && index < data.length;
        index += step
      ) {
        if (this.canOpenDrilldown(this.drilldownMetric, data[index]))
          return index;
      }

      return null;
    },
    canOpenDrilldown(metric, dataPoint) {
      if (!dataPoint) return false;

      if (this.isAverageMetricType(metric.KEY)) {
        return dataPoint.count > 0;
      }

      return dataPoint.value > 0;
    },
    closeDrilldown() {
      this.drilldownRequest = null;
      this.drilldownMetric = null;
      this.drilldownIndex = null;
    },
  },
};
</script>

<template>
  <section class="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
    <article
      v-for="metric in metrics"
      :key="metric.KEY"
      class="rounded-2xl border border-n-weak bg-n-solid-1 p-4 shadow-sm transition hover:border-n-blue-5 hover:shadow-md"
    >
      <div class="flex items-center gap-3">
        <span
          class="grid size-11 shrink-0 place-items-center rounded-xl"
          :class="metricTheme(metric.KEY).tone"
        >
          <span class="size-5" :class="metricTheme(metric.KEY).icon" />
        </span>
        <ChartStats
          class="min-w-0"
          :metric="metric"
          :account-summary-key="accountSummaryKey"
          :summary-fetching-key="summaryFetchingKey"
        />
      </div>
    </article>
  </section>

  <section class="mt-4 grid grid-cols-1 gap-4 xl:grid-cols-2">
    <article
      v-for="metric in metrics"
      :key="`${metric.KEY}-chart`"
      class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm transition hover:border-n-blue-5 hover:shadow-md"
    >
      <header class="flex items-start justify-between gap-3">
        <div class="flex min-w-0 items-start gap-3">
          <span
            class="grid size-10 shrink-0 place-items-center rounded-xl"
            :class="metricTheme(metric.KEY).tone"
          >
            <span class="size-5" :class="metricTheme(metric.KEY).icon" />
          </span>
          <div class="min-w-0">
            <h3 class="truncate text-base font-semibold text-n-slate-12">
              {{ metric.NAME }}
            </h3>
            <p v-if="metric.DESC" class="mt-1 text-xs text-n-slate-10">
              {{ metric.DESC }}
            </p>
          </div>
        </div>
        <span
          v-if="metric.INFO_TEXT"
          v-tooltip.top="metric.INFO_TEXT"
          class="i-lucide-info size-4 shrink-0 text-n-slate-9"
        />
      </header>
      <div class="mt-5 h-72 rounded-xl bg-n-alpha-1 p-3">
        <woot-loading-state
          v-if="accountReport.isFetching[metric.KEY]"
          class="text-xs"
          :message="$t('REPORT.LOADING_CHART')"
        />
        <div v-else class="flex h-full items-center justify-center">
          <BarChart
            v-if="accountReport.data[metric.KEY].length"
            :collection="getCollection(metric)"
            :chart-options="getChartOptions(metric)"
            :clickable="isDrilldownEnabled()"
            @element-click="onChartElementClick(metric, $event)"
          />
          <span v-else class="text-sm text-n-slate-10">
            {{ $t('REPORT.NO_ENOUGH_DATA') }}
          </span>
        </div>
      </div>
    </article>
  </section>
  <ReportDrilldownDrawer
    :id="drilldownRequest?.id"
    :open="!!drilldownRequest"
    :metric="drilldownRequest?.metric"
    :metric-name="drilldownRequest?.metricName"
    :bucket-label="drilldownRequest?.bucketLabel"
    :bucket-timestamp="drilldownRequest?.bucketTimestamp"
    :bucket-value="drilldownRequest?.bucketValue"
    :is-average-metric="drilldownRequest?.isAverageMetric"
    :from="drilldownRequest?.from"
    :to="drilldownRequest?.to"
    :type="drilldownRequest?.type"
    :group-by="drilldownRequest?.groupBy"
    :business-hours="drilldownRequest?.businessHours"
    :can-prev="canDrilldownPrev"
    :can-next="canDrilldownNext"
    @navigate="navigateDrilldown"
    @close="closeDrilldown"
  />
</template>
