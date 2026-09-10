<script setup>
import Policy from 'dashboard/components/policy.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  subtitle: {
    type: String,
    required: true,
  },
  actionPerms: {
    type: Array,
    default: () => [],
  },
  showBackdrop: {
    type: Boolean,
    default: true,
  },
});
</script>

<template>
  <section
    class="relative flex flex-col items-center justify-center w-full h-full overflow-hidden"
  >
    <div
      class="relative w-full max-w-5xl mx-auto overflow-hidden h-full max-h-[28rem]"
    >
      <div
        v-if="showBackdrop"
        class="w-full h-full space-y-4 overflow-y-hidden opacity-25 pointer-events-none dark:opacity-50"
      >
        <slot name="empty-state-item" />
      </div>
      <div
        class="flex flex-col items-center justify-end w-full h-full pb-20"
        :class="{
          'absolute inset-x-0 bottom-0 bg-gradient-to-t from-white from-30% via-white/95 via-65% to-transparent dark:from-n-surface-1 dark:via-n-surface-1/90':
            showBackdrop,
        }"
      >
        <div
          class="flex flex-col items-center justify-center gap-6 rounded-3xl border border-[#dce7f2] bg-white/95 px-10 py-8 shadow-[0_18px_55px_rgba(8,43,82,0.13)] dark:border-transparent dark:bg-transparent dark:px-0 dark:py-0 dark:shadow-none"
          :class="{
            'mt-48': !showBackdrop,
          }"
        >
          <div class="flex flex-col items-center justify-center gap-3">
            <h2 class="text-3xl font-medium text-center text-n-slate-12">
              {{ title }}
            </h2>
            <p
              v-if="subtitle"
              class="max-w-xl text-base text-center text-n-slate-11 tracking-[0.3px]"
            >
              {{ subtitle }}
            </p>
          </div>
          <Policy :permissions="actionPerms">
            <slot name="actions" />
          </Policy>
        </div>
      </div>
    </div>
  </section>
</template>
