<script setup>
defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  icon: { type: String, default: '' },
  flush: { type: Boolean, default: false },
});
</script>

<template>
  <section
    class="overflow-hidden rounded-2xl border border-n-weak bg-n-solid-2 shadow-sm"
  >
    <header
      class="flex flex-wrap items-center justify-between gap-3 border-b border-n-weak px-5 py-4"
    >
      <div class="flex min-w-0 items-center gap-2">
        <span
          v-if="icon"
          class="flex size-8 shrink-0 items-center justify-center rounded-xl bg-n-blue-3 text-n-blue-11"
        >
          <i class="size-4" :class="icon" />
        </span>
        <div class="min-w-0">
          <h3 class="font-semibold text-n-slate-12">{{ title }}</h3>
          <p v-if="description" class="mt-0.5 text-xs text-n-slate-10">
            {{ description }}
          </p>
        </div>
      </div>
      <slot name="actions" />
    </header>
    <div :class="flush ? '' : 'p-5'">
      <slot />
    </div>
  </section>
</template>
