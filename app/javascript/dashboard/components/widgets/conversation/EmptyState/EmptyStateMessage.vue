<script setup>
defineProps({
  message: {
    type: String,
    required: true,
  },
});

const EMPTY_STATE_TEXT = Object.freeze({
  title: 'Você está em dia!',
  detail: 'Quando algo novo chegar, você verá por aqui.',
  viewConversations: 'Ver conversas',
  createFilter: 'Criar filtro',
  tipTitle: 'Dica JRC',
  tip: 'Use filtros e etiquetas para organizar melhor suas conversas.',
});
</script>

<template>
  <div
    class="relative flex h-full w-full flex-col items-center justify-center overflow-hidden bg-n-surface-1 px-8 text-center"
  >
    <div
      aria-hidden="true"
      class="absolute left-1/2 top-1/2 size-[42rem] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[radial-gradient(circle,rgba(8,124,240,0.09),transparent_68%)]"
    />
    <div class="relative flex w-full max-w-xl flex-col items-center">
      <div
        class="relative mb-8 grid size-32 place-items-center rounded-[2.25rem] bg-n-blue-3/70 text-n-brand shadow-[0_20px_60px_rgba(8,124,240,0.16)]"
      >
        <span class="i-lucide-inbox size-16" />
        <span
          class="absolute -right-9 top-1 grid h-12 w-[4.5rem] place-items-center rounded-2xl rounded-bl-sm bg-n-brand text-white shadow-lg"
        >
          <span class="i-lucide-message-circle-more size-7" />
        </span>
      </div>
      <h2 class="text-3xl font-semibold tracking-tight text-[#082b52]">
        {{ EMPTY_STATE_TEXT.title }}
      </h2>
      <p class="mt-3 max-w-lg text-base leading-7 text-n-slate-10">
        {{ message }}<br />
        <span>{{ EMPTY_STATE_TEXT.detail }}</span>
      </p>
      <div class="mt-8 flex items-center gap-3">
        <RouterLink
          :to="{ name: 'home' }"
          class="flex h-12 items-center gap-2 rounded-xl bg-n-brand px-6 text-sm font-semibold text-white shadow-[0_8px_22px_rgba(8,124,240,0.25)] transition hover:brightness-110"
        >
          <span class="i-lucide-messages-square size-5" />
          <span>{{ EMPTY_STATE_TEXT.viewConversations }}</span>
        </RouterLink>
        <RouterLink
          :to="{ name: 'search' }"
          class="flex h-12 items-center gap-2 rounded-xl border border-n-weak bg-n-solid-1 px-6 text-sm font-semibold text-n-slate-12 transition hover:border-n-blue-7 hover:text-n-brand"
        >
          <span class="i-lucide-list-filter size-5" />
          <span>{{ EMPTY_STATE_TEXT.createFilter }}</span>
        </RouterLink>
      </div>
      <div
        class="mt-8 flex w-full items-start gap-4 rounded-2xl border border-n-blue-4/60 bg-n-blue-2/50 p-5 text-start"
      >
        <span
          class="i-lucide-sparkles mt-0.5 size-6 flex-shrink-0 text-n-brand"
        />
        <div>
          <p class="text-sm font-semibold text-n-brand">
            {{ EMPTY_STATE_TEXT.tipTitle }}
          </p>
          <p class="mt-1 text-sm leading-5 text-n-slate-11">
            {{ EMPTY_STATE_TEXT.tip }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
