import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ErpClient, cnpj } from '../src/client.mjs';
const secrets = { KSYS_HELPDESK_API_TOKEN: 'test', KSYS_BEMTEVI_TENANT_TOKEN: 'test', BEMTEVI_API_TOKEN: 'test' };
const binding = { cnpj: '28240080000171', bemtevi_customer_id: '152', helpdesk_company_id: '536' };
function client({ duplicate = false, wrongCustomer = false, wrongTicket = false } = {}) {
  return new ErpClient(secrets, async url => {
    if (url.pathname === '/cliente') return { data: { cpfcnpj: binding.cnpj, cod_cliente: wrongCustomer ? 999 : 152, nome: 'Cliente autorizado', centralassinantesenha: 'must-never-leak' } };
    if (url.pathname === '/cobrancas') return { data: [{ cod_cliente: wrongTicket ? 3 : 152, codcobranca: 100, valorcobranca: '100.00', datavencimento: '2026-09-10' }] };
    if (url.pathname.endsWith('/clientes.php')) return { status: 1, data: { totalPages: 2, clientes: url.searchParams.get('page') === '1' || duplicate ? [{ NUM_CNPJ: binding.cnpj, COD_EMPRESA: 536 }] : [] } };
    return { status: 1, data: { tickets: [{ COD_EMPRESA: wrongTicket ? 3 : 536, COD_SOLICITACAO: 10, NOM_ASSUNTO: '<b>Suporte</b>', COD_STATUS: 1 }] } };
  });
}
test('preserva CNPJ e rejeita identificador incompleto', () => { assert.equal(cnpj('28.240.080/0001-71'), binding.cnpj); assert.throws(() => cnpj('123')); });
test('resolve cliente nas páginas e preserva códigos distintos', async () => { const data = await client().resolve(binding.cnpj); assert.equal(data.bemtevi_customer_id, '152'); assert.equal(data.helpdesk_company_id, '536'); assert.ok(!JSON.stringify(data).includes('must-never-leak')); });
test('rejeita CNPJ duplicado em outra página', async () => { await assert.rejects(client({ duplicate: true }).resolve(binding.cnpj), /ambiguous/); });
test('rejeita troca de cliente no BEMTEVI', async () => { await assert.rejects(client({ wrongCustomer: true }).context(binding, 'nico'), /mismatch/); });
test('rejeita ticket de outra empresa mesmo se o ERP ignorar filtro', async () => { await assert.rejects(client({ wrongTicket: true }).context(binding, 'nico'), /mismatch/); });
test('contexto não inclui senha nem HTML; informa paginação', async () => { const data = JSON.stringify(await client().context(binding, 'suporte_n1')); assert.ok(!data.includes('must-never-leak')); assert.ok(!data.includes('<b>')); assert.ok(data.includes('primeira página')); });
test('financeiro usa cobrança do cliente e não infere pagamento', async () => { const data = await client().context(binding, 'financeiro'); assert.ok(data.some(item => item.text.includes('100.00'))); assert.ok(data.some(item => item.text.includes('sem comprovação de pagamento'))); });
test('rejeita cobrança de outro cliente', async () => { await assert.rejects(client({ wrongTicket: true }).context(binding, 'financeiro'), /charge_customer_mismatch/); });
test('aceita lista de cliente e rejeita correspondência duplicada', async () => {
  const service = client(); const original = service.transport;
  service.transport = async (url, options) => { const data = await original(url, options); return url.pathname === '/cliente' ? { data: [data.data] } : data; };
  assert.equal((await service.resolve(binding.cnpj)).bemtevi_customer_id, '152');
  service.transport = async () => ({ data: [{ cpfcnpj: binding.cnpj }, { cpfcnpj: binding.cnpj }] });
  await assert.rejects(service.resolve(binding.cnpj), /ambiguous/);
});
test('não soma linhas repetidas de uma cobrança', async () => {
  const service = client(); const original = service.transport;
  service.transport = async (url, options) => { const data = await original(url, options); return url.pathname === '/cobrancas' ? { data: [data.data[0], data.data[0]] } : data; };
  const items = await service.context(binding, 'financeiro');
  assert.equal(items.filter(item => item.kind.startsWith('charge-')).length, 1);
  assert.ok(items.some(item => item.text.includes('Valor consolidado não confirmado')));
  assert.ok(!JSON.stringify(items).includes('100.00'));
});
