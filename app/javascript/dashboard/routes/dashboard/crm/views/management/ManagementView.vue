<template>
  <div class="management-view p-6 h-full flex flex-col bg-n-solid-2">
    <div class="flex items-center justify-between mb-6">
      <h2 class="text-2xl font-bold text-n-slate-12">Gestão de Equipe</h2>
      <select class="border border-n-weak rounded px-3 py-1.5 text-sm">
        <option value="this_month">Este Mês</option>
        <option value="last_month">Mês Passado</option>
        <option value="this_year">Este Ano</option>
      </select>
    </div>

    <div class="flex-1 overflow-auto">
      <table
        class="min-w-full divide-y divide-n-weak text-sm border border-n-weak rounded-lg overflow-hidden"
      >
        <thead class="bg-n-alpha-2">
          <tr>
            <th
              class="px-6 py-3 text-left text-xs font-medium text-n-slate-10 uppercase tracking-wider"
            >
              Agente
            </th>
            <th
              class="px-6 py-3 text-right text-xs font-medium text-n-slate-10 uppercase tracking-wider"
            >
              Negócios Abertos
            </th>
            <th
              class="px-6 py-3 text-right text-xs font-medium text-n-slate-10 uppercase tracking-wider"
            >
              Negócios Ganhos
            </th>
            <th
              class="px-6 py-3 text-right text-xs font-medium text-n-slate-10 uppercase tracking-wider"
            >
              Receita Ganha
            </th>
            <th
              class="px-6 py-3 text-right text-xs font-medium text-n-slate-10 uppercase tracking-wider"
            >
              Taxa de Conversão
            </th>
          </tr>
        </thead>
        <tbody class="bg-n-solid-2 divide-y divide-n-weak">
          <tr>
            <td colspan="5" class="px-6 py-12 text-center text-n-slate-10">
              Carregando métricas da equipe...
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup></script>

