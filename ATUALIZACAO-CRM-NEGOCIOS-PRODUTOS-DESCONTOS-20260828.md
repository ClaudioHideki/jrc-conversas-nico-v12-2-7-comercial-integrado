# Atualização CRM — 28/08/2026

## Negócios
- Ao criar a partir de uma conversa, backend reaproveita contato, origem do canal e responsável (assignee) quando disponíveis.
- Cadastro rápido de cliente dentro do modal de Novo Negócio.
- Origem padronizada em combo (WhatsApp, Ligações, Ligações WhatsApp, E-mail, Instagram, Facebook, Webchat, Indicação, Campanha, Prospecção ativa e Outro).
- Produtos podem ser adicionados antes de salvar o negócio.
- Tabela comercial com quantidade, preço unitário, desconto em R$ e total.
- Valor do negócio é recalculado pelos itens quando há produtos.
- Painel lateral passa a exibir cliente, origem e produtos vinculados.

## Backend de produtos do negócio
- CRUD aninhado em `/crm/deals/:deal_id/products`.
- Reutiliza `jrc_crm_deal_products` já existente; não exige migration nova.
- Recalcula `value_cents` do negócio a partir dos itens.

## Propostas
- Mantido o desconto por item já suportado pelo backend e agora exposto na tabela da proposta.
- Adicionado desconto comercial adicional em R$ antes do envio.
- Total é recalculado após alteração do desconto comercial.

## Observação
- Envio automático de proposta por WhatsApp/e-mail e geração do PDF institucional não foram acoplados nesta etapa, pois dependem da definição final do canal de envio e do template comercial JRC.
