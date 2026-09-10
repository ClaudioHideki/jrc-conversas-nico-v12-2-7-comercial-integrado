export const fixtureBinding = { cnpj: '11222333000181', name: 'Cliente fictício GoPure', bemtevi_customer_id: '900001', helpdesk_company_id: '900002' };
export function fixtureContext() {
  return [
    { kind: 'fixture', text: 'SIMULAÇÃO: todos os dados ERP a seguir são fictícios; nenhum ERP foi consultado.' },
    { kind: 'customer', text: 'Cliente fictício GoPure. Solicita expansão de 5 para 10 ramais e treinamento.' },
    { kind: 'ticket-900003', text: 'SIMULAÇÃO: chamado 900003 sobre áudio unilateral em um ramal. Em análise; não existe diagnóstico confirmado nem SLA medido.' },
    { kind: 'finance-limit', text: 'SIMULAÇÃO: cliente pede segunda via. Não há cobrança, valor ou link verificado. Encaminhar ao financeiro humano.' },
  ];
}
