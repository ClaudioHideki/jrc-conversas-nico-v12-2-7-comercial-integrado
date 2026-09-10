<template>
  <div
    class="modal fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
  >
    <div
      class="bg-n-solid-2 rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col"
    >
      <div
        class="flex items-center justify-between p-4 border-b border-n-weak"
      >
        <h3 class="text-lg font-bold text-n-slate-12">Construtor de Proposta</h3>
        <button class="text-n-slate-10 hover:text-n-slate-11">
          <i class="i-lucide-x w-5 h-5"></i>
        </button>
      </div>

      <div class="flex-1 overflow-y-auto p-6 bg-n-alpha-2">
        <div class="bg-n-solid-2 p-5 rounded border border-n-weak mb-4">
          <div class="mb-4">
            <label class="block text-sm font-medium text-n-slate-11 mb-1"
              >Título da Proposta</label
            >
            <input
              type="text"
              class="w-full border border-n-weak rounded px-3 py-2 text-sm"
              placeholder="Ex: Proposta Comercial - Empresa X"
            />
          </div>
        </div>

        <div class="bg-n-solid-2 p-5 rounded border border-n-weak mb-4">
          <h4 class="font-bold text-n-slate-12 mb-4">Itens</h4>
          <table class="min-w-full text-sm mb-4">
            <thead class="bg-n-alpha-2 border-y border-n-weak">
              <tr>
                <th class="px-4 py-2 text-left">Produto</th>
                <th class="px-4 py-2 text-right">Qtd</th>
                <th class="px-4 py-2 text-right">Preço Unitário</th>
                <th class="px-4 py-2 text-right">Total</th>
                <th class="px-4 py-2"></th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td colspan="5" class="px-4 py-8 text-center text-n-slate-10">
                  Nenhum item adicionado
                </td>
              </tr>
            </tbody>
          </table>
          <button
            class="text-n-blue-11 hover:text-n-blue-11 text-sm font-medium border border-n-blue-6 px-3 py-1.5 rounded"
          >
            + Adicionar Produto
          </button>
        </div>

        <div
          class="bg-n-solid-2 p-5 rounded border border-n-weak flex justify-end"
        >
          <div class="w-64 text-sm">
            <div class="flex justify-between py-1">
              <span class="text-n-slate-11">Subtotal</span
              ><span class="font-medium">R$ 0,00</span>
            </div>
            <div class="flex justify-between py-1">
              <span class="text-n-slate-11">Desconto</span
              ><span class="font-medium">R$ 0,00</span>
            </div>
            <div
              class="flex justify-between py-2 border-t mt-2 text-base font-bold"
            >
              <span class="text-n-slate-12">Total</span
              ><span class="text-n-teal-11">R$ 0,00</span>
            </div>
          </div>
        </div>
      </div>

      <div class="p-4 border-t border-n-weak bg-n-solid-2 flex justify-end gap-3">
        <button
          class="px-4 py-2 text-sm font-medium text-n-slate-11 bg-n-solid-2 border border-n-weak rounded hover:bg-n-alpha-2"
        >
          Cancelar
        </button>
        <button
          class="px-4 py-2 text-sm font-medium text-n-slate-11 bg-n-solid-2 border border-n-weak rounded hover:bg-n-alpha-2"
        >
          Salvar Rascunho
        </button>
        <button
          class="px-4 py-2 text-sm font-medium text-white bg-n-brand rounded hover:bg-n-blue-11"
        >
          Pré-visualizar e Enviar
        </button>
      </div>
    </div>
  </div>
</template>

<script setup></script>


