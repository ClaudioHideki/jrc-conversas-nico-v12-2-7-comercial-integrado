export class ErpError extends Error {}
export function cnpj(value) {
  const normalized = String(value ?? '').replace(/\D/g, '');
  if (!/^\d{14}$/.test(normalized)) throw new ErpError('invalid_cnpj');
  return normalized;
}
export function identifier(value) {
  if (!/^[1-9]\d{0,12}$/.test(String(value ?? ''))) throw new ErpError('invalid_identifier');
  return String(value);
}
const text = value => String(value ?? '').replace(/<[^>]*>/g, '').slice(0, 700);
function selectCustomer(data, target) {
  const rows = Array.isArray(data) ? data : [data];
  const matches = rows.filter(row => String(row?.cpfcnpj ?? '').replace(/\D/g, '') === target);
  if (matches.length !== 1) throw new ErpError('customer_ambiguous_or_missing');
  return matches[0];
}
export class ErpClient {
  constructor(secrets, transport) { this.secrets = secrets; this.transport = transport; }
  async get(system, path, body) {
    const helpdesk = system === 'helpdesk';
    const token = helpdesk ? this.secrets.KSYS_HELPDESK_API_TOKEN : this.secrets.BEMTEVI_API_TOKEN;
    if (!token || (helpdesk && !this.secrets.KSYS_BEMTEVI_TENANT_TOKEN)) throw new ErpError('credentials_missing');
    const headers = helpdesk ? { Authorization: `Bearer ${token}`, 'Authorization-Bemtevi': `Bearer ${this.secrets.KSYS_BEMTEVI_TENANT_TOKEN}` } : { token };
    const base = helpdesk ? 'https://api.ksys.net.br/php-helpdesk/' : 'https://api-bemtevi.ksys.net.br/';
    // Node fetch forbids GET bodies. Use the same bounded native transport for both APIs.
    const response = await this.transport(new URL(path, base), { method: 'GET', headers, body });
    if (helpdesk && response.status !== 1) throw new ErpError('erp_rejected');
    return response.data;
  }
  async resolve(value) {
    const target = cnpj(value);
    const customer = selectCustomer(await this.get('bemtevi', 'cliente', { cpfcnpj: target }), target);
    const matches = [];
    let totalPages = 1;
    for (let page = 1; page <= totalPages; page += 1) {
      const data = await this.get('helpdesk', `clientes.php?limit=200&page=${page}`);
      if (!Array.isArray(data?.clientes) || !Number.isInteger(data.totalPages) || data.totalPages < 1 || data.totalPages > 50) throw new ErpError('unsupported_pagination');
      if (page > 1 && totalPages !== data.totalPages) throw new ErpError('pagination_changed');
      totalPages = data.totalPages;
      for (const row of data.clientes) if (String(row.NUM_CNPJ ?? '').replace(/\D/g, '') === target) matches.push(row);
    }
    if (matches.length !== 1) throw new ErpError('customer_ambiguous_or_missing');
    return { cnpj: target, name: text(customer.nome), bemtevi_customer_id: identifier(customer.cod_cliente), helpdesk_company_id: identifier(matches[0].COD_EMPRESA) };
  }
  async context(binding, agent) {
    const target = cnpj(binding.cnpj);
    const customerId = identifier(binding.bemtevi_customer_id);
    const companyId = identifier(binding.helpdesk_company_id);
    const customer = selectCustomer(await this.get('bemtevi', 'cliente', { cpfcnpj: target }), target);
    if (cnpj(customer?.cpfcnpj) !== target || identifier(customer?.cod_cliente) !== customerId) throw new ErpError('customer_mismatch');
    const items = [{ kind: 'customer', text: `Cadastro BEMTEVI confirmado: ${text(customer.nome)}. CNPJ ${target}. Situação cadastral (código do ERP): ${text(customer.situacao)}. Não é confirmação de pagamento.` }];
    if (['nico', 'cx', 'suporte_n1', 'implantacao', 'supervisor'].includes(agent)) {
      const data = await this.get('helpdesk', `tickets.php?cod_empresa=${companyId}&limit=10&page=1`);
      if (!Array.isArray(data?.tickets)) throw new ErpError('unsupported_ticket_schema');
      for (const ticket of data.tickets.slice(0, 8)) {
        if (identifier(ticket.COD_EMPRESA) !== companyId) throw new ErpError('ticket_customer_mismatch');
        items.push({ kind: `ticket-${identifier(ticket.COD_SOLICITACAO)}`, text: `Chamado ${identifier(ticket.COD_SOLICITACAO)}: ${text(ticket.NOM_ASSUNTO)}. Status Help Desk (código): ${text(ticket.COD_STATUS)}. Criado: ${text(ticket.DAT_CADASTRO)}. SLA não disponível nesta consulta.` });
      }
      items.push({ kind: 'ticket-scope', text: 'Consulta limitada à primeira página de até 10 chamados; até 8 apresentados. Não representa todo o histórico.' });
    }
    if (agent === 'financeiro') {
      const charges = await this.get('bemtevi', 'cobrancas', { codcliente: Number(customerId), abertas: true });
      if (!Array.isArray(charges)) throw new ErpError('unsupported_charges_schema');
      for (const charge of charges) if (identifier(charge.cod_cliente) !== customerId) throw new ErpError('charge_customer_mismatch');
      const groups = new Map();
      for (const charge of charges) {
        const code = identifier(charge.codcobranca);
        groups.set(code, [...(groups.get(code) || []), charge]);
      }
      for (const [code, rows] of [...groups].slice(0, 8)) {
        if (rows.length > 1) {
          items.push({ kind: `charge-${code}`, text: `Cobrança BEMTEVI ${code}: retorno com várias linhas para o mesmo código. Valor consolidado não confirmado; solicitar conferência humana. Não somar linhas nem apresentar como dívidas separadas.` });
          continue;
        }
        const charge = rows[0];
        const amount = String(charge.valorcobranca ?? '');
        const due = String(charge.datavencimento ?? '');
        if (!/^\d{1,10}([.,]\d{1,2})?$/.test(amount) || !/^\d{4}-\d{2}-\d{2}(?:[ T]00:00:00)?$/.test(due)) throw new ErpError('unsupported_charge_values');
        items.push({ kind: `charge-${identifier(charge.codcobranca)}`, text: `Cobrança BEMTEVI ${identifier(charge.codcobranca)}. Valor informado pelo ERP: ${amount}; vencimento: ${due}. Retornada pelo filtro abertas; sem comprovação de pagamento/baixa neste retorno.` });
      }
      items.push({ kind: 'finance-limit', text: `Mostrados até 8 de ${groups.size} códigos de cobrança retornados. Segunda via, negociação e envio de cobrança não habilitados. Não afirmar saldo total, pagamento ou baixa.` });
    }
    return items.slice(0, 10);
  }
}
