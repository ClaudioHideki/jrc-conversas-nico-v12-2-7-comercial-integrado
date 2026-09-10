<script setup>
import { computed } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ContactSortMenu from './components/ContactSortMenu.vue';
import ContactMoreActions from './components/ContactMoreActions.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import { usePolicy } from 'dashboard/composables/usePolicy';

defineProps({
  showSearch: { type: Boolean, default: true },
  searchValue: { type: String, default: '' },
  headerTitle: { type: String, required: true },
  buttonLabel: { type: String, default: '' },
  activeSort: { type: String, default: 'last_activity_at' },
  activeOrdering: { type: String, default: '' },
  isSegmentsView: { type: Boolean, default: false },
  hasActiveFilters: { type: Boolean, default: false },
  isLabelView: { type: Boolean, default: false },
  isActiveView: { type: Boolean, default: false },
});

const emit = defineEmits([
  'search',
  'filter',
  'update:sort',
  'add',
  'import',
  'export',
  'createSegment',
  'deleteSegment',
]);

const { checkPermissions } = usePolicy();
const canManageContacts = computed(() =>
  checkPermissions(['administrator', 'contact_manage'])
);
</script>

<template>
  <header
    class="sticky top-0 z-20 border-b border-n-weak bg-n-surface-1 px-6"
  >
    <div
      class="mx-auto flex w-full max-w-6xl flex-col gap-4 py-5 lg:flex-row lg:items-center lg:justify-between"
    >
      <span class="text-xl font-semibold tracking-tight text-n-slate-12">
        {{ headerTitle }}
      </span>
      <div
        class="flex w-full flex-col gap-3 lg:w-auto lg:flex-row lg:items-center"
      >
        <div v-if="showSearch" class="flex min-w-0 items-center gap-2 lg:w-72">
          <Input
            :model-value="searchValue"
            type="search"
            :placeholder="$t('CONTACTS_LAYOUT.HEADER.SEARCH_PLACEHOLDER')"
            :custom-input-class="[
              'h-8 [&:not(.focus)]:!border-transparent bg-n-alpha-2 dark:bg-n-solid-1 ltr:!pl-8 !py-1 rtl:!pr-8',
            ]"
            class="w-full"
            @input="emit('search', $event.target.value)"
          >
            <template #prefix>
              <Icon
                icon="i-lucide-search"
                class="absolute -translate-y-1/2 text-n-slate-11 size-4 top-1/2 ltr:left-2 rtl:right-2"
              />
            </template>
          </Input>
        </div>
        <div class="flex flex-wrap items-center gap-3">
          <div
            class="flex items-center gap-1 rounded-xl border border-n-weak bg-n-solid-1 p-1 shadow-sm"
          >
            <div v-if="!isLabelView && !isActiveView" class="relative">
              <Button
                id="toggleContactsFilterButton"
                v-tooltip.top="$t('CONTACTS_LAYOUT.FILTER.TITLE')"
                :icon="
                  isSegmentsView ? 'i-lucide-pen-line' : 'i-lucide-list-filter'
                "
                color="slate"
                size="sm"
                class="relative w-8"
                :variant="hasActiveFilters ? 'faded' : 'ghost'"
                @click="emit('filter')"
              >
                <div
                  v-if="hasActiveFilters && !isSegmentsView"
                  class="absolute top-0 right-0 w-2 h-2 rounded-full bg-n-brand"
                />
              </Button>
              <slot name="filter" />
            </div>
            <Button
              v-if="
                hasActiveFilters &&
                !isSegmentsView &&
                !isLabelView &&
                !isActiveView
              "
              v-tooltip.top="$t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.CONFIRM')"
              icon="i-lucide-save"
              color="slate"
              size="sm"
              variant="ghost"
              @click="emit('createSegment')"
            />
            <Button
              v-if="isSegmentsView && !isLabelView && !isActiveView"
              v-tooltip.top="$t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.DELETE_SEGMENT.CONFIRM')"
              icon="i-lucide-trash"
              color="slate"
              size="sm"
              variant="ghost"
              @click="emit('deleteSegment')"
            />
            <ContactSortMenu
              :active-sort="activeSort"
              :active-ordering="activeOrdering"
              @update:sort="emit('update:sort', $event)"
            />
            <ContactMoreActions
              @add="emit('add')"
              @import="emit('import')"
              @export="emit('export')"
            />
          </div>
          <div class="flex flex-wrap items-center gap-2">
            <Button
              :label="$t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.ADD_CONTACT')"
              icon="i-lucide-plus"
              color="teal"
              size="sm"
              class="shadow-sm"
              @click="emit('add')"
            />
            <Button
              v-if="canManageContacts"
              :label="$t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.IMPORT_CONTACT')"
              icon="i-lucide-download"
              color="blue"
              variant="faded"
              size="sm"
              @click="emit('import')"
            />
            <Button
              v-if="canManageContacts"
              :label="$t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.EXPORT_CONTACT')"
              icon="i-lucide-upload"
              color="slate"
              variant="outline"
              size="sm"
              @click="emit('export')"
            />
          </div>
          <ComposeConversation>
            <template #trigger>
              <Button
                :label="buttonLabel"
                icon="i-lucide-send"
                size="sm"
                class="shadow-sm"
              />
            </template>
          </ComposeConversation>
        </div>
      </div>
    </div>
  </header>
</template>
