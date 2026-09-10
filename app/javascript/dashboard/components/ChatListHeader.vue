<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { formatNumber } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';

import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';
import SwitchLayout from 'dashboard/routes/dashboard/conversation/search/SwitchLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  pageTitle: { type: String, required: true },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  activeStatus: { type: String, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
]);

const { uiSettings, updateUISettings } = useUISettings();
const { t } = useI18n();
const UI_TEXT = Object.freeze({
  searchPlaceholder: 'Buscar na caixa de entrada...',
  filter: 'Filtrar',
  saveFilter: 'Salvar filtro',
  deleteFilter: 'Excluir filtro',
  clear: 'Limpar',
});

const displayTitle = computed(() =>
  props.pageTitle === t('CHAT_LIST.TAB_HEADING')
    ? 'Caixa de Entrada'
    : props.pageTitle
);

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

const allCount = computed(() => props.conversationStats?.allCount || 0);
const formattedAllCount = computed(() => formatNumber(allCount.value));
const statusLabel = computed(() =>
  t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${props.activeStatus}.TEXT`)
);

const toggleConversationLayout = () => {
  const { LAYOUT_TYPES } = wootConstants;
  const {
    conversation_display_type: conversationDisplayType = LAYOUT_TYPES.CONDENSED,
  } = uiSettings.value;
  const newViewType =
    conversationDisplayType === LAYOUT_TYPES.CONDENSED
      ? LAYOUT_TYPES.EXPANDED
      : LAYOUT_TYPES.CONDENSED;
  updateUISettings({
    conversation_display_type: newViewType,
    previously_used_conversation_display_type: newViewType,
  });
};
</script>

<template>
  <div
    class="flex flex-col gap-4 border-b border-n-weak bg-n-solid-1 px-5 pb-4 pt-5"
    :class="{
      'border-n-strong': hasAppliedFiltersOrActiveFolders,
    }"
  >
    <div class="flex items-center justify-between gap-3">
      <div class="flex min-w-0 items-center gap-2">
        <h1
          class="truncate text-2xl font-semibold tracking-tight text-n-slate-12"
          :title="displayTitle"
        >
          {{ displayTitle }}
        </h1>
        <span
          v-if="allCount > 0 && !isListLoading"
          class="grid h-6 min-w-6 place-items-center rounded-full bg-n-blue-3 px-1.5 text-xs font-semibold text-n-brand"
        >
          {{ formattedAllCount }}
        </span>
        <span class="sr-only">{{ statusLabel }}</span>
      </div>
      <div class="flex items-center gap-1">
        <ConversationBasicFilter
          v-if="!hasAppliedFiltersOrActiveFolders"
          :is-on-expanded-layout="isOnExpandedLayout"
          @change-filter="onBasicFilterChange"
        />
        <SwitchLayout
          :is-on-expanded-layout="isOnExpandedLayout"
          @toggle="toggleConversationLayout"
        />
      </div>
    </div>

    <div class="flex items-center gap-2">
      <RouterLink
        :to="{ name: 'search' }"
        class="flex h-10 min-w-0 flex-1 items-center gap-2 rounded-xl border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-10 transition hover:border-n-blue-7"
      >
        <span class="i-lucide-search size-4 flex-shrink-0" />
        <span class="truncate">{{ UI_TEXT.searchPlaceholder }}</span>
      </RouterLink>
      <div class="relative">
        <NextButton
          id="toggleConversationFilterButton"
          :label="UI_TEXT.filter"
          icon="i-lucide-list-filter"
          slate
          sm
          outline
          @click="emit('filtersModal')"
        />
        <div
          id="conversationFilterTeleportTarget"
          class="absolute z-50 mt-2 ltr:right-0 rtl:left-0"
        />
      </div>
    </div>

    <div v-if="hasAppliedFilters || hasActiveFolders" class="flex gap-2">
      <NextButton
        v-if="hasAppliedFilters && !hasActiveFolders"
        :label="UI_TEXT.saveFilter"
        icon="i-lucide-save"
        slate
        sm
        faded
        @click="emit('addFolders')"
      />
      <NextButton
        v-if="hasActiveFolders"
        :label="UI_TEXT.deleteFilter"
        icon="i-lucide-trash-2"
        ruby
        sm
        faded
        @click="emit('deleteFolders')"
      />
      <NextButton
        :label="UI_TEXT.clear"
        icon="i-lucide-circle-x"
        ruby
        sm
        faded
        @click="emit('resetFilters')"
      />
      <div id="saveFilterTeleportTarget" class="absolute z-50 mt-2" />
    </div>
  </div>
</template>
