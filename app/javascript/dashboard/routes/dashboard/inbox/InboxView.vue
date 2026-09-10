<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import SidepanelSwitch from 'dashboard/components-next/Conversation/SidepanelSwitch.vue';

import ConversationBox from 'dashboard/components/widgets/conversation/ConversationBox.vue';
import InboxEmptyState from './InboxEmptyState.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ConversationSidebar from 'dashboard/components/widgets/conversation/ConversationSidebar.vue';

const route = useRoute();
const store = useStore();
const { uiSettings } = useUISettings();

const isConversationLoading = ref(false);
const currentChat = useMapGetter('getSelectedChat');
const conversationById = useMapGetter('getConversationById');

const inboxId = computed(() => Number(route.params.inboxId));
const conversationId = computed(() => Number(route.params.id));
const showEmptyState = computed(() => !conversationId.value);

const isContactPanelOpen = computed(() => {
  if (!currentChat.value.id) return false;
  return uiSettings.value.is_contact_sidebar_open;
});

const setActiveChat = async conversation => {
  if (!conversation) return;
  await store.dispatch('setActiveChat', { data: conversation });
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE);
};

const fetchConversationById = async () => {
  if (!conversationId.value) return;

  store.dispatch('clearSelectedState');
  const existingConversation = conversationById.value(conversationId.value);
  if (existingConversation) {
    await setActiveChat(existingConversation);
    return;
  }

  isConversationLoading.value = true;
  try {
    await store.dispatch('getConversation', conversationId.value);
    await setActiveChat(conversationById.value(conversationId.value));
  } finally {
    isConversationLoading.value = false;
  }
};

watch(conversationId, fetchConversationById, { immediate: true });

onMounted(async () => {
  await store.dispatch('agents/get');
});
</script>

<template>
  <main class="h-full min-w-0 flex-1 bg-n-background">
    <div v-if="showEmptyState" class="flex h-full w-full">
      <InboxEmptyState />
    </div>
    <div v-else class="h-full p-0 lg:p-3 lg:pl-0">
      <div
        v-if="isConversationLoading"
        class="grid h-full place-items-center rounded-2xl border border-n-weak bg-n-solid-1"
      >
        <Spinner class="text-n-brand" />
      </div>
      <div v-else class="flex h-full min-w-0 gap-3">
        <ConversationBox
          class="min-w-0 flex-1 overflow-hidden border-n-weak bg-n-solid-1 shadow-sm lg:rounded-2xl lg:border"
          is-inbox-view
          :inbox-id="inboxId"
          :is-on-expanded-layout="false"
        >
          <SidepanelSwitch v-if="currentChat.id && !isContactPanelOpen" />
        </ConversationBox>
        <ConversationSidebar
          v-if="isContactPanelOpen"
          class="overflow-hidden border-n-weak bg-n-solid-1 shadow-sm lg:!rounded-2xl lg:!border"
          :current-chat="currentChat"
        />
      </div>
    </div>
  </main>
</template>
