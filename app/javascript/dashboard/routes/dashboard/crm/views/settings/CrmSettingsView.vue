<template>
  <div class="settings-view p-6 h-full flex flex-col bg-n-alpha-2">
    <h2 class="text-2xl font-bold text-n-slate-12 mb-6">Configurações CRM</h2>

    <div
      class="bg-n-solid-2 border border-n-weak rounded-lg shadow-sm flex flex-col h-full overflow-hidden"
    >
      <div class="border-b border-n-weak bg-n-alpha-2 px-4 py-2 flex gap-4">
        <button
          class="px-4 py-2 text-sm font-medium text-n-blue-11 border-b-2 border-n-brand"
        >
          Funis de Vendas
        </button>
        <button
          class="px-4 py-2 text-sm font-medium text-n-slate-11 hover:text-n-slate-12"
        >
          Motivos de Perda
        </button>
        <button
          class="px-4 py-2 text-sm font-medium text-n-slate-11 hover:text-n-slate-12"
        >
          Geral
        </button>
      </div>

      <div class="p-6 flex-1 overflow-auto">
        <h3 class="text-lg font-semibold text-n-slate-12 mb-4">
          Gerenciar Funis e Etapas
        </h3>
        <p class="text-sm text-n-slate-11 mb-6">
          Crie funis de vendas e configure as etapas pelas quais seus negócios
          passarão.
        </p>
        <button
          class="text-n-blue-11 font-medium text-sm border border-n-blue-6 px-4 py-2 rounded hover:bg-n-blue-3"
        >
          + Adicionar Funil
        </button>
      </div>
    </div>
  </div>
</template>
<script setup></script>


