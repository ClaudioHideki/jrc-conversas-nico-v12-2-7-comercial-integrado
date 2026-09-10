# CRM JRC — qualificação, conversão e contraste

## Escopo entregue

Esta etapa mantém o CRM dentro do JRC Conversas (Rails 7.1 + Vue 3) e não altera os módulos de Conversas, Contatos, Relatórios, Ramal ou Videoconferência.

- Ciclo público do lead: **Novo**, **Em contato**, **Qualificado**, **Convertido** e **Descartado**.
- Alteração de status por API sem recarregar a aplicação inteira, com atualização local da linha e auditoria de valor anterior, novo valor, usuário e horário.
- Ações contextuais: marcar como qualificado, converter em negócio, abrir negócio, voltar à conversa e abrir contato.
- Modal de conversão preenchido com os dados disponíveis do lead, contato, empresa, produto/interesse, valor, funil, etapa, probabilidade, fechamento e observações.
- Conversão transacional e idempotente. Repetir a requisição devolve o mesmo negócio e não cria duplicidade.
- Conversa de origem preservada no lead e no negócio, incluindo canal, caixa, última mensagem, agente e equipe quando disponíveis.
- Indicadores com períodos de 30 dias, 90 dias e ano, filtro de responsável somente para administrador e filtro de funil quando existe mais de um.
- Ranking e proposta pública sem nomes, valores ou contatos fictícios; as telas consomem exclusivamente as APIs reais do CRM.
- Tokens visuais do JRC aplicados às telas do CRM para contraste consistente nos temas claro e escuro.
- Associação definitiva `JrcCrm::ImportBatch#import_row_errors`, sem sobrescrever `ActiveModel#errors`.

O Cockpit, alertas de Cockpit e automações de cross-sell/upsell não fazem parte desta entrega.

## Banco de dados

A migration aditiva `20260826000019_add_conversion_key_to_jrc_crm_deals.rb` adiciona `conversion_key` e um índice único parcial por conta. Não remove nem renomeia dados existentes.

Antes de produção, faça backup e execute:

```sh
bundle exec rails db:migrate
bundle exec rails db:migrate:status
```

O rollback operacional preferido continua sendo desabilitar a feature flag `jrc_crm`. Não faça rollback cego de várias migrations em produção.

## Instalação e início

```sh
cp .env.example .env
bundle install
pnpm install
bundle exec rails db:prepare
foreman start -f Procfile.dev
```

Com Docker:

```sh
docker compose up -d postgres redis
docker compose run --rm rails bundle exec rails db:prepare
docker compose up rails vite sidekiq
```

Ative `jrc_crm` somente nas contas piloto depois de validar permissões e contagens.

## Validações desta entrega

- Migration aplicada em PostgreSQL 16 temporário: **aprovada**.
- Build Vue/Vite de produção com heap de 4 GB: **aprovado** (5.035 módulos).
- ESLint nos arquivos funcionais modificados: **zero erros**; permanecem avisos de formatação não bloqueantes.
- Testes Rails essenciais: **6 exemplos, zero falhas**.
- Testes das APIs de leads e negócios: **8 exemplos, zero falhas**.

## Pendências reais

- A árvore CRM herdada ainda contém violações antigas de ESLint em telas estruturais como Ranking, Automações e Campanhas. Elas não impedem o build, mas não foram declaradas como corrigidas nesta etapa.
- O aviso do Vite sobre `/brand-assets/jrc-background.jpeg` já existia e continua resolvido em runtime.
- O primeiro build atingiu o heap padrão do Node; com `NODE_OPTIONS=--max-old-space-size=4096` o build concluiu normalmente.
- A validação visual do pacote deve ser repetida no LAB após descompactar esta cópia, pois o `localhost:3000` ativo durante a geração está montado em outra pasta (`Desktop/CRM-Indicadores`).

## Arquivos centrais alterados

- `app/controllers/api/v1/accounts/crm/leads_controller.rb`
- `app/services/jrc_crm/lead_conversion_service.rb`
- `app/services/jrc_crm/conversation_lead_service.rb`
- `app/models/jrc_crm/lead.rb`, `deal.rb` e `import_batch.rb`
- `app/serializers/jrc_crm/lead_serializer.rb`
- `app/javascript/dashboard/routes/dashboard/crm/views/leads/*`
- `app/javascript/dashboard/routes/dashboard/crm/views/reports/ReportsView.vue`
- componentes compartilhados de badges e contraste das telas CRM
- specs de serviço e API de leads
