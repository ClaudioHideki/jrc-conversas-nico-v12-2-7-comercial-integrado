# CRM JRC — indicadores e modernização visual

Esta entrega moderniza somente o módulo CRM do JRC Conversas. A arquitetura Rails/Vue, as rotas já existentes, o banco e o fluxo conversa → lead foram preservados.

## Entregue

- Nova aba **Indicadores** no menu do CRM.
- Filtros de período: últimos 30 dias, últimos 90 dias e ano atual.
- Indicadores reais de leads, negócios, pipeline, receita, conversão e ticket médio.
- Distribuição por etapa do funil.
- Origem dos leads por canal.
- Situação de leads, negócios e propostas.
- Produtividade de atividades: concluídas, pendentes e atrasadas.
- Receita ganha por responsável.
- Cabeçalho e navegação do CRM com aparência mais atual.
- Botões, cartões, filtros, tabelas e estados vazios modernizados.
- Funil Kanban com colunas e cartões mais coloridos.
- Identidade visual aplicada a Leads, Negócios, Carteira, Atividades, Agenda, Produtos e Propostas.

## Fora desta etapa

- Cockpit do agente.
- Alertas ou lembretes disparados pelo Cockpit.
- Automações de cross-sell e upsell.

## Banco de dados

Esta etapa não cria migrações e não altera tabelas. O endpoint de indicadores é somente de leitura e calcula os resultados usando os registros atuais do CRM.

## Validação realizada

- Build Vite de produção concluído.
- ESLint sem erros nos arquivos alterados.
- RuboCop sem apontamentos no endpoint novo.
- 13 testes de serviço e API do CRM, sem falhas.
