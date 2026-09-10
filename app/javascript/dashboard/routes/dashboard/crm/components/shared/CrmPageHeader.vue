<script setup>
defineProps({
  eyebrow: { type: String, default: '' },
  title: { type: String, required: true },
  description: { type: String, default: '' },
  icon: { type: String, default: 'i-lucide-chart-no-axes-combined' },
  tone: {
    type: String,
    default: 'blue',
    validator: value =>
      ['blue', 'teal', 'iris', 'amber', 'ruby'].includes(value),
  },
});

const toneClasses = {
  blue: 'bg-n-blue-3 text-n-blue-11 ring-n-blue-6',
  teal: 'bg-n-teal-3 text-n-teal-11 ring-n-teal-6',
  iris: 'bg-n-iris-3 text-n-iris-11 ring-n-iris-6',
  amber: 'bg-n-amber-3 text-n-amber-11 ring-n-amber-6',
  ruby: 'bg-n-ruby-3 text-n-ruby-11 ring-n-ruby-6',
};
</script>

<template>
  <header class="flex flex-wrap items-start justify-between gap-4">
    <div class="flex min-w-0 items-start gap-3">
      <span
        class="mt-0.5 flex size-12 shrink-0 items-center justify-center rounded-2xl ring-1 shadow-sm"
        :class="toneClasses[tone]"
      >
        <i class="size-5" :class="icon" />
      </span>
      <div class="min-w-0">
        <p
          v-if="eyebrow"
          class="text-xs font-semibold uppercase tracking-[0.16em] text-n-brand"
        >
          {{ eyebrow }}
        </p>
        <h2 class="text-2xl font-bold tracking-tight text-n-slate-12">
          {{ title }}
        </h2>
        <p v-if="description" class="mt-1 text-sm text-n-slate-10">
          {{ description }}
        </p>
        <div v-if="$slots.meta" class="mt-2 flex flex-wrap items-center gap-2">
          <slot name="meta" />
        </div>
      </div>
    </div>
    <div v-if="$slots.actions" class="flex flex-wrap items-center gap-2">
      <slot name="actions" />
    </div>
  </header>
</template>
