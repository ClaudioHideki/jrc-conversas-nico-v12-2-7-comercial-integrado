<script setup>
import { computed } from 'vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import {
  CHANNEL_TYPES,
  getInboxChannelKey,
} from 'dashboard/helper/inbox';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const channelKey = computed(() => getInboxChannelKey(props.inbox));
const badgeClass = computed(() => {
  const tones = {
    [CHANNEL_TYPES.WHATSAPP]: 'border-n-teal-7 bg-n-teal-3 text-n-teal-11',
    [CHANNEL_TYPES.FACEBOOK]: 'border-n-blue-7 bg-n-blue-3 text-n-blue-11',
    [CHANNEL_TYPES.INSTAGRAM]: 'border-n-ruby-7 bg-n-ruby-3 text-n-ruby-11',
    [CHANNEL_TYPES.EMAIL]: 'border-n-cyan-7 bg-n-cyan-3 text-n-cyan-11',
    [CHANNEL_TYPES.API]: 'border-n-amber-7 bg-n-amber-3 text-n-amber-11',
    [CHANNEL_TYPES.SMS]: 'border-n-violet-7 bg-n-violet-3 text-n-violet-11',
    [CHANNEL_TYPES.WEBSITE]: 'border-n-slate-7 bg-n-slate-3 text-n-slate-11',
    [CHANNEL_TYPES.TELEGRAM]: 'border-n-blue-7 bg-n-blue-3 text-n-blue-11',
    [CHANNEL_TYPES.LINE]: 'border-n-teal-7 bg-n-teal-3 text-n-teal-11',
    [CHANNEL_TYPES.TIKTOK]: 'border-n-slate-7 bg-n-slate-3 text-n-slate-12',
  };
  return tones[channelKey.value] || 'border-n-weak bg-n-alpha-2 text-n-slate-11';
});
</script>

<template>
  <div
    :title="inbox.name"
    class="inline-flex min-w-0 max-w-full items-center gap-1 rounded-full border px-2 py-0.5"
    :class="badgeClass"
  >
    <ChannelIcon
      :inbox="inbox"
      use-brand-icon
      class="size-3.5 flex-shrink-0"
    />
    <span class="truncate text-label-small font-medium">
      {{ inbox.name }}
    </span>
  </div>
</template>
