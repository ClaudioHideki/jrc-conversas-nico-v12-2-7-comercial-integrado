<script setup>
import { computed } from 'vue';

const props = defineProps({
  opportunity: { type: Object, required: true },
});

defineEmits(['open']);

const channelIcon = computed(() => {
  const channel = props.opportunity.source_channel?.toLowerCase() || '';
  if (channel.includes('whatsapp')) return 'i-lucide-message-circle';
  if (channel.includes('email')) return 'i-lucide-mail';
  if (channel.includes('facebook')) return 'i-lucide-messages-square';
  if (channel.includes('instagram')) return 'i-lucide-instagram';
  if (channel.includes('telegram')) return 'i-lucide-send';
  if (channel.includes('voice') || channel.includes('phone'))
    return 'i-lucide-phone';
  return 'i-lucide-messages-square';
});

const isOverdue = computed(
  () => props.opportunity.next_activity?.status === 'overdue'
);

const temperatureClass = computed(
  () =>
    ({
      cold: 'bg-n-blue-3 text-n-blue-11',
      warm: 'bg-n-amber-3 text-n-amber-11',
      hot: 'bg-n-orange-3 text-n-orange-11',
      very_hot: 'bg-n-ruby-3 text-n-ruby-11',
    })[props.opportunity.temperature]
);

const formattedValue = computed(() => {
  if (props.opportunity.value === null) return '';
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'BRL',
  }).format(Number(props.opportunity.value));
});
</script>

<template>
  <button
    type="button"
    class="w-full text-left rounded-xl border border-n-weak bg-n-solid-2 p-3 shadow-sm transition hover:border-n-strong hover:shadow-md"
    @click="$emit('open', opportunity)"
  >
    <div class="flex items-start justify-between gap-2">
      <div class="min-w-0">
        <p class="truncate text-sm font-semibold text-n-slate-12">
          {{ opportunity.title }}
        </p>
        <p class="mt-0.5 truncate text-xs text-n-slate-11">
          {{ opportunity.contact.name || opportunity.contact.identifier }}
        </p>
        <p
          v-if="opportunity.contact.company"
          class="truncate text-xs text-n-slate-10"
        >
          {{ opportunity.contact.company }}
        </p>
      </div>
      <span
        :class="channelIcon"
        class="mt-0.5 size-4 shrink-0 text-n-slate-10"
      />
    </div>
    <p
      v-if="opportunity.product_name"
      class="mt-3 truncate text-xs text-n-slate-11"
    >
      {{ opportunity.product_name }}
    </p>
    <div class="mt-3 flex items-center justify-between gap-2">
      <span class="text-sm font-medium text-n-slate-12">{{
        formattedValue
      }}</span>
      <span
        :class="temperatureClass"
        class="rounded-full px-2 py-0.5 text-[11px] font-medium"
      >
        {{ $t(`SALES.TEMPERATURES.${opportunity.temperature}`) }}
      </span>
    </div>
    <div
      v-if="opportunity.next_activity"
      class="mt-3 flex items-center gap-1.5 rounded-md px-2 py-1.5 text-xs"
      :class="
        isOverdue
          ? 'bg-n-ruby-3 text-n-ruby-11'
          : 'bg-n-alpha-2 text-n-slate-11'
      "
    >
      <span
        :class="isOverdue ? 'i-lucide-clock-alert' : 'i-lucide-calendar-clock'"
        class="size-3.5"
      />
      <span class="truncate">{{ opportunity.next_activity.title }}</span>
      <time class="ml-auto shrink-0">{{
        new Date(opportunity.next_activity.scheduled_at).toLocaleString()
      }}</time>
    </div>
    <div
      class="mt-3 flex items-center justify-between text-[11px] text-n-slate-10"
    >
      <span class="truncate">{{ opportunity.owner?.name }}</span>
      <time>{{ new Date(opportunity.updated_at).toLocaleDateString() }}</time>
    </div>
  </button>
</template>
