# CRM JRC — etapa 1

Esta entrega mantém o CRM dentro do JRC Conversas (Rails + Vue) e não instala o aplicativo Next.js de referência como um segundo sistema.

## Entregue

- Navegação comercial multiabas com os módulos nativos já funcionais.
- Dashboard comercial reorganizado com indicadores reais do banco.
- Funil Kanban com cabeçalho e acesso rápido para nova oportunidade.
- Minha Carteira preservada como visão operacional do responsável.
- Ação **Transformar em lead** dentro da barra lateral da conversa.
- Lead vinculado ao contato, conversa, canal de origem, agente e equipe.
- Botão **Voltar à conversa** na listagem de leads.
- Proteção idempotente: repetir a classificação não cria outro lead.
- Registro da criação no histórico de auditoria do CRM.

## Banco de dados

A migração `20260825000018_add_conversation_classification_to_jrc_crm_leads.rb` é somente aditiva. Ela inclui:

- `jrc_crm_leads.idempotency_key`
- `jrc_crm_leads.classified_at`
- índice único parcial por conta e chave de idempotência

Nenhuma tabela ou dado existente é removido.

## Atualização

Depois de substituir/mesclar os arquivos da aplicação, execute:

```bash
bundle exec rails db:migrate
```

Em seguida, reinicie os processos Rails, Sidekiq e Vite/frontend usados pela instalação.

## Validação realizada

- Migrações completas em PostgreSQL 16 isolado.
- 13 testes de serviço e API do CRM, sem falhas.
- ESLint nos arquivos frontend alterados, sem erros.
- Build Vite de produção concluído.
