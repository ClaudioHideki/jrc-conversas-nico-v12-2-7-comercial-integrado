<script setup>
import { reactive, watch } from 'vue';

const props = defineProps({
  filters: { type: Object, required: true },
  metadata: { type: Object, required: true },
  stages: { type: Array, required: true },
  channels: { type: Array, required: true },
});

const emit = defineEmits(['apply', 'clear']);
const localFilters = reactive({ ...props.filters });
watch(
  () => props.filters,
  value => Object.assign(localFilters, value),
  { deep: true }
);
const apply = () => emit('apply', { ...localFilters });

const controlClass =
  'h-9 rounded-lg border border-n-weak bg-n-solid-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand';
</script>

<template>
  <div
    class="flex flex-wrap items-end gap-2 rounded-xl border border-n-weak bg-n-solid-2 p-3"
  >
    <select
      v-model="localFilters.owner_id"
      :class="controlClass"
      :aria-label="$t('SALES.FILTERS.OWNER')"
    >
      <option value="">{{ $t('SALES.FILTERS.ALL_OWNERS') }}</option>
      <option v-for="user in metadata.users" :key="user.id" :value="user.id">
        {{ user.name }}
      </option>
    </select>
    <select
      v-model="localFilters.team_id"
      :class="controlClass"
      :aria-label="$t('SALES.FILTERS.TEAM')"
    >
      <option value="">{{ $t('SALES.FILTERS.ALL_TEAMS') }}</option>
      <option v-for="team in metadata.teams" :key="team.id" :value="team.id">
        {{ team.name }}
      </option>
    </select>
    <select
      v-model="localFilters.channel"
      :class="controlClass"
      :aria-label="$t('SALES.FILTERS.CHANNEL')"
    >
      <option value="">{{ $t('SALES.FILTERS.ALL_CHANNELS') }}</option>
      <option v-for="channel in channels" :key="channel" :value="channel">
        {{ channel }}
      </option>
    </select>
    <select
      v-model="localFilters.stage_id"
      :class="controlClass"
      :aria-label="$t('SALES.FILTERS.STAGE')"
    >
      <option value="">{{ $t('SALES.FILTERS.ALL_STAGES') }}</option>
      <option v-for="stage in stages" :key="stage.id" :value="stage.id">
        {{ stage.name }}
      </option>
    </select>
    <input
      v-model="localFilters.product"
      :class="controlClass"
      :placeholder="$t('SALES.FILTERS.PRODUCT')"
    />
    <select
      v-model="localFilters.temperature"
      :class="controlClass"
      :aria-label="$t('SALES.FILTERS.TEMPERATURE')"
    >
      <option value="">{{ $t('SALES.FILTERS.ALL_TEMPERATURES') }}</option>
      <option
        v-for="temperature in ['cold', 'warm', 'hot', 'very_hot']"
        :key="temperature"
        :value="temperature"
      >
        {{ $t(`SALES.TEMPERATURES.${temperature}`) }}
      </option>
    </select>
    <select
      v-model="localFilters.status"
      :class="controlClass"
      :aria-label="$t('SALES.FILTERS.STATUS')"
    >
      <option value="">{{ $t('SALES.FILTERS.ALL_STATUSES') }}</option>
      <option
        v-for="status in ['open', 'won', 'lost']"
        :key="status"
        :value="status"
      >
        {{ $t(`SALES.STATUSES.${status}`) }}
      </option>
    </select>
    <input
      v-model="localFilters.from"
      type="date"
      :class="controlClass"
      :aria-label="$t('SALES.FILTERS.FROM')"
    />
    <input
      v-model="localFilters.to"
      type="date"
      :class="controlClass"
      :aria-label="$t('SALES.FILTERS.TO')"
    />
    <button
      type="button"
      class="h-9 rounded-lg bg-n-brand px-4 text-sm font-medium text-white"
      @click="apply"
    >
      {{ $t('SALES.FILTERS.APPLY') }}
    </button>
    <button
      type="button"
      class="h-9 rounded-lg px-3 text-sm text-n-slate-11 hover:bg-n-alpha-2"
      @click="$emit('clear')"
    >
      {{ $t('SALES.FILTERS.CLEAR') }}
    </button>
  </div>
</template>
