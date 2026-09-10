<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import SipCredentialsAPI from 'dashboard/api/sipCredentials';
import WhatsappCallingConfigurationAPI from 'dashboard/api/whatsappCallingConfiguration';

const route = useRoute();
const router = useRouter();
const sipConfigured = ref(false);
const whatsappConfigured = ref(false);
const loading = ref(true);

const openRoute = name =>
  router.push({ name, params: { accountId: route.params.accountId } });

onMounted(async () => {
  const [sipResult, whatsappResult] = await Promise.allSettled([
    SipCredentialsAPI.getMine(),
    WhatsappCallingConfigurationAPI.get(),
  ]);
  if (sipResult.status === 'fulfilled') {
    sipConfigured.value = Boolean(
      sipResult.value.data?.configured && sipResult.value.data?.enabled
    );
  }
  if (whatsappResult.status === 'fulfilled') {
    const data = whatsappResult.value;
    whatsappConfigured.value = Boolean(
      data?.enabled || data?.configured || data?.inbox_id || data?.inboxId
    );
  }
  loading.value = false;
});
</script>

<template>
  <main class="h-full overflow-auto bg-gradient-to-br from-teal-50/60 via-n-surface-1 to-blue-50/70 p-4 sm:p-6">
    <div class="mx-auto flex max-w-[1400px] flex-col gap-5">
      <header class="rounded-3xl border border-teal-200 bg-white p-6 shadow-sm dark:bg-n-solid-2">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="flex items-start gap-4"><span class="flex size-12 items-center justify-center rounded-2xl bg-teal-600 text-white shadow-md"><span class="i-lucide-phone-call size-6" /></span><div><h1 class="text-3xl font-bold text-n-slate-12">Chamadas</h1><p class="mt-1 text-sm text-n-slate-10">Acesso separado para Ramal JRC, WhatsApp Calling e retornos comerciais.</p></div></div>
          <button class="rounded-xl border border-n-weak bg-n-solid-2 px-4 py-2.5 text-sm font-semibold" @click="openRoute('jrc_cockpit')">Cockpit</button>
        </div>
      </header>

      <div v-if="loading" class="flex min-h-64 items-center justify-center rounded-3xl border border-n-weak bg-white dark:bg-n-solid-2"><span class="i-lucide-loader-circle size-6 animate-spin text-teal-600" /></div>
      <section v-else class="grid gap-5 lg:grid-cols-2">
        <article class="rounded-3xl border border-blue-200 bg-white p-6 shadow-sm dark:bg-n-solid-2">
          <div class="flex items-center justify-between"><span class="flex size-12 items-center justify-center rounded-2xl bg-blue-600 text-white shadow"><span class="i-lucide-phone size-6" /></span><span class="rounded-full px-3 py-1 text-xs font-semibold" :class="sipConfigured ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700'">{{ sipConfigured ? 'Configurado' : 'Não configurado' }}</span></div>
          <h2 class="mt-5 text-2xl font-bold text-n-slate-12">Ramal JRC</h2>
          <p class="mt-2 text-sm leading-relaxed text-n-slate-10">Ligações convencionais pelo softphone, com teclado, transferência, pausa e histórico.</p>
          <div class="mt-5 flex gap-2"><button class="rounded-xl bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white shadow-md disabled:opacity-50" :disabled="!sipConfigured" @click="openRoute('ramal_index')">Abrir ramal</button><button class="rounded-xl border border-blue-200 px-4 py-2.5 text-sm font-semibold text-blue-700" @click="openRoute('ramal_index')">Configurar</button></div>
        </article>
        <article class="rounded-3xl border border-emerald-200 bg-white p-6 shadow-sm dark:bg-n-solid-2">
          <div class="flex items-center justify-between"><span class="flex size-12 items-center justify-center rounded-2xl bg-emerald-600 text-white shadow"><span class="i-ri-whatsapp-fill size-6" /></span><span class="rounded-full px-3 py-1 text-xs font-semibold" :class="whatsappConfigured ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700'">{{ whatsappConfigured ? 'Configurado' : 'Validar configuração' }}</span></div>
          <h2 class="mt-5 text-2xl font-bold text-n-slate-12">WhatsApp Calling</h2>
          <p class="mt-2 text-sm leading-relaxed text-n-slate-10">Permissão, chamada, controles e registro da próxima ação dentro do contexto do cliente.</p>
          <button class="mt-5 rounded-xl bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white shadow-md" @click="openRoute('whatsapp_calling_index')">Abrir WhatsApp Calling</button>
        </article>
      </section>

      <section class="rounded-3xl border border-violet-200 bg-white p-6 shadow-sm dark:bg-n-solid-2">
        <div class="flex flex-wrap items-center justify-between gap-4"><div><h2 class="text-lg font-bold text-n-slate-12">Depois da chamada</h2><p class="mt-1 text-sm text-n-slate-10">Registre resultado, anotação e próxima atividade para não perder o acompanhamento.</p></div><div class="flex gap-2"><button class="rounded-xl bg-violet-600 px-4 py-2.5 text-sm font-semibold text-white" @click="openRoute('crm_calendar')">Agendar retorno</button><button class="rounded-xl border border-violet-200 px-4 py-2.5 text-sm font-semibold text-violet-700" @click="openRoute('crm_activities')">Ver atividades</button></div></div>
      </section>
    </div>
  </main>
</template>
