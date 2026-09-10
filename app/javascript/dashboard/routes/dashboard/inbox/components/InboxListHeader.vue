<script>
import { useAlert, useTrack } from 'dashboard/composables';
import { INBOX_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';

import NextButton from 'dashboard/components-next/button/Button.vue';
import InboxOptionMenu from './InboxOptionMenu.vue';
import InboxDisplayMenu from './InboxDisplayMenu.vue';

export default {
  components: {
    NextButton,
    InboxOptionMenu,
    InboxDisplayMenu,
  },
  props: {
    isContextMenuOpen: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['redirect', 'filter'],
  data() {
    return {
      showInboxDisplayMenu: false,
      showInboxOptionMenu: false,
    };
  },
  watch: {
    isContextMenuOpen: {
      handler(val) {
        if (val) {
          this.showInboxDisplayMenu = false;
          this.showInboxOptionMenu = false;
        }
      },
      immediate: true,
    },
  },
  methods: {
    markAllRead() {
      useTrack(INBOX_EVENTS.MARK_ALL_NOTIFICATIONS_AS_READ);
      this.$store.dispatch('notifications/readAll').then(() => {
        useAlert(this.$t('INBOX.ALERTS.MARK_ALL_READ'));
      });
    },
    deleteAll() {
      this.$store.dispatch('notifications/deleteAll').then(() => {
        useAlert(this.$t('INBOX.ALERTS.DELETE_ALL'));
      });
    },
    deleteAllRead() {
      this.$store.dispatch('notifications/deleteAllRead').then(() => {
        useAlert(this.$t('INBOX.ALERTS.DELETE_ALL_READ'));
      });
    },
    openInboxDisplayMenu() {
      this.showInboxDisplayMenu = !this.showInboxDisplayMenu;
    },
    openInboxOptionsMenu() {
      this.showInboxOptionMenu = !this.showInboxOptionMenu;
    },
    onInboxOptionMenuClick(key) {
      const actions = {
        mark_all_read: () => this.markAllRead(),
        delete_all: () => this.deleteAll(),
        delete_all_read: () => this.deleteAllRead(),
      };
      const action = actions[key];
      if (action) action();
      this.$emit('redirect');
    },
    onFilterChange(option) {
      this.$emit('filter', option);
      this.showInboxDisplayMenu = false;
      this.$emit('redirect');
    },
  },
};
</script>

<template>
  <div
    class="flex w-full flex-col gap-4 border-b border-n-weak bg-n-solid-1 px-4 pb-4 pt-5"
  >
    <div class="flex w-full items-center justify-between gap-2">
      <h1
        class="truncate text-2xl font-semibold tracking-tight text-[#082b52] min-w-0"
      >
        {{ $t('INBOX.LIST.TITLE') }}
      </h1>
      <div class="relative flex items-center gap-1">
        <NextButton
          icon="i-lucide-sliders-vertical"
          slate
          sm
          :variant="showInboxOptionMenu ? 'faded' : 'ghost'"
          @click="openInboxOptionsMenu"
        />
        <InboxOptionMenu
          v-if="showInboxOptionMenu"
          v-on-clickaway="openInboxOptionsMenu"
          class="absolute top-full z-30 mt-1 ltr:right-0 rtl:left-0"
          @option-click="onInboxOptionMenuClick"
        />
      </div>
    </div>
    <div class="flex w-full items-center gap-2">
      <RouterLink
        :to="{ name: 'search' }"
        class="flex h-10 min-w-0 flex-1 items-center gap-2 rounded-xl border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-10 transition hover:border-n-blue-7"
      >
        <span class="i-lucide-search size-4 flex-shrink-0" />
        <span class="truncate">{{ $t('COMBOBOX.SEARCH_PLACEHOLDER') }}</span>
      </RouterLink>
      <div class="relative">
        <NextButton
          :label="$t('INBOX.LIST.DISPLAY_DROPDOWN')"
          icon="i-lucide-list-filter"
          slate
          sm
          :variant="showInboxDisplayMenu ? 'faded' : 'outline'"
          @click="openInboxDisplayMenu"
        />
        <InboxDisplayMenu
          v-if="showInboxDisplayMenu"
          v-on-clickaway="openInboxDisplayMenu"
          class="absolute z-30 mt-1 top-full ltr:right-0 rtl:left-0"
          @filter="onFilterChange"
        />
      </div>
    </div>
  </div>
</template>
