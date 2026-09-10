<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { useJrcCopilot } from 'dashboard/components-next/jrcCopilot/useJrcCopilot';

const { open, openWithPrompt } = useJrcCopilot();
const shortcuts = [
  { label: 'O que precisa da minha atencao?', prompt: 'O que precisa da minha atencao agora? Organize por urgencia.' },
  { label: 'Resumir meu dia', prompt: 'Resuma meu dia com atendimentos, retornos, agenda e oportunidades.' },
  { label: 'Analisar minhas filas', prompt: 'Analise minhas filas e identifique riscos de SLA e clientes aguardando.' },
  { label: 'Organizar proximas acoes', prompt: 'Organize minhas proximas acoes por impacto e prazo.' },
];
</script>

<template>
  <main class="h-full overflow-auto bg-[radial-gradient(circle_at_top_right,rgba(83,213,235,0.18),transparent_34%),linear-gradient(135deg,#f3f8fc,#eef4ff)] p-4 sm:p-6">
    <div class="mx-auto max-w-[1450px] space-y-5">
      <section class="relative min-h-[420px] overflow-hidden rounded-3xl border border-cyan-200/70 bg-[#073b64] p-8 text-white shadow-xl">
        <div class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_75%_20%,rgba(55,218,241,0.28),transparent_35%)]" />
        <div class="relative z-10 max-w-2xl"><span class="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-wider text-cyan-100"><span class="i-lucide-sparkles size-4" /> IA operacional JRC</span><h1 class="mt-5 text-4xl font-bold leading-tight sm:text-5xl">O Copiloto JRC aparece somente quando voc&ecirc; precisa.</h1><p class="mt-5 max-w-xl text-base leading-relaxed text-cyan-50/90">O mascote permanece no canto inferior da tela. Ao clicar, abre a conversa lateral e coordena os Agentes IA de Prioridades, Atendimento, Qualidade, Retorno, Comercial, Agenda, SLA e Supervis&atilde;o.</p><button class="mt-7 inline-flex items-center gap-2 rounded-xl bg-white px-5 py-3 font-semibold text-[#075a87] shadow-lg" @click="open"><i class="i-lucide-message-circle size-5" /> Abrir Copiloto JRC</button></div>
        <img :src="'/brand-assets/jrc-copilot-character.png'" alt="Mascote oficial do Copiloto JRC" class="pointer-events-none absolute -bottom-16 right-6 hidden w-[430px] opacity-95 lg:block" />
      </section>
      <section class="grid gap-4 md:grid-cols-2 xl:grid-cols-4"><button v-for="shortcut in shortcuts" :key="shortcut.label" class="rounded-2xl border border-[#dbe7f5] bg-white p-5 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-blue-300 hover:shadow-md" @click="openWithPrompt(shortcut.prompt)"><span class="grid size-10 place-content-center rounded-xl bg-gradient-to-br from-cyan-50 to-violet-100 text-blue-700"><i class="i-lucide-sparkles size-5" /></span><b class="mt-4 block text-[#172033]">{{ shortcut.label }}</b><span class="mt-2 inline-block text-xs font-semibold text-blue-600">Perguntar agora &rarr;</span></button></section>
    </div>
  </main>
</template>
