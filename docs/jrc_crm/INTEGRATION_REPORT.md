# CRM nativo JRC Conversas — relatório de integração

Data da integração: 24/08/2026.

## Resultado

O pacote `JRC_CRM_MODULO_NATIVO_V1_20260824_1529.zip` foi usado como fonte, não como patch cego. Os patches textuais do pacote não foram aplicados porque divergiam da árvore real e parte das telas/controladores era apenas estrutural. O núcleo foi adaptado ao Rails 7.1, Vue 3, Vuex, rotas, feature flags, sidebar e identidade já existentes no JRC Conversas.

O módulo anterior `sales_*` permanece intacto. Nenhum registro foi apagado e a importação para `jrc_crm_*` é opcional, explícita e idempotente.

## Funcionalidades implementadas e expostas

- Feature flag `jrc_crm` no backend e frontend, com bloqueio também em acesso direto às rotas.
- Item CRM na sidebar entre Contatos e Relatórios. Quando `jrc_crm` está ativo, o item Vendas não é duplicado; `/vendas/pipeline` redireciona ao novo funil.
- Isolamento por `account_id`, escopo por proprietário para agentes e visão da própria conta para administradores.
- Pipeline padrão e etapas criados de forma idempotente.
- Dashboard com métricas reais, leads, negócios, lista de negócios e Kanban.
- Drag-and-drop persistente, locking otimista, ganho/perda e motivo de perda obrigatório.
- Cards com contato, valor, responsável, origem, próxima atividade e atraso.
- Painel lateral resumido do negócio e retorno direto à conversa vinculada.
- Leads com criação, busca, status e conversão transacional em contato/negócio.
- Negócios ligados a contato, conversa, agente, equipe e origem.
- Widget CRM na sidebar da conversa, com criação de negócio e atividade já contextualizadas.
- Atividades, conclusão, atrasos e agenda baseada em registros reais.
- Minha Carteira baseada no usuário atual, com opção de visão ampla restrita ao administrador.
- Catálogo de produtos com criação restrita a administrador.
- Propostas geradas a partir dos produtos do negócio, token público armazenado somente como digest, expiração/revogação e endpoints públicos limitados à conta.
- Timeline e auditoria backend para mudanças importantes.
- Filas Sidekiq dedicadas adicionadas sem remover filas existentes.
- Importador opcional `sales_*` para CRM com referências legadas únicas, preservação de valores, origem, proprietário, contato, conversa, equipe, atividades e histórico de etapas.

## Funcionalidades preparadas, mas não declaradas prontas

Os arquivos de arquitetura para ranking, relatórios comerciais avançados, campanhas, automações, importação CSV genérica, configuração e n8n foram mantidos, porém suas rotas/telas não são expostas. Eles precisam de regras de negócio, autorização e testes adicionais antes de ativação.

Também permanecem pendentes:

- editor completo de itens/descontos e página pública Vue para propostas;
- timeline/histórico completo dentro do painel lateral do negócio;
- painel dedicado de ramal e histórico de ligações no negócio (a conversa vinculada continua dando acesso aos recursos existentes);
- testes manuais de tema claro/escuro, sidebar recolhida, login, WhatsApp, e-mail, ramal, videoconferência e relatórios legados;
- teste de inicialização real do processo Sidekiq e do servidor Vite em modo desenvolvimento;
- ranking e relatórios comerciais avançados com dados reais.

## Feature flag

Habilitar para uma conta:

```bash
bundle exec rails runner "Account.find(1).enable_features!('jrc_crm')"
```

Desabilitar, sem apagar dados:

```bash
bundle exec rails runner "Account.find(1).disable_features!('jrc_crm')"
```

Desabilitada, a flag remove o item da sidebar, impede as rotas Vue e retorna HTTP 403 nas APIs do CRM.

## Instalação e banco

Faça backup do PostgreSQL antes de qualquer alteração:

```bash
pg_dump --format=custom --file=jrc_before_crm.dump "$DATABASE_URL"
bundle exec rails db:chatwoot_prepare
```

O comando oficial do projeto deve ser usado em local/LAB primeiro. As migrations somente criam/adicionam estruturas `jrc_crm_*`; elas não removem `sales_*`.

## Importação opcional do Vendas anterior

Primeiro mantenha o CRM desabilitado, faça backup e confira as contagens por conta. Em seguida:

```bash
bundle exec rake jrc_crm:import_sales ACCOUNT_ID=1
```

O importador pode ser executado novamente: índices e IDs legados impedem duplicação. Ele não exclui nem altera os registros de origem. Depois compare contagens/valores, valide amostras no LAB e somente então habilite `jrc_crm`.

Sem importação, Vendas continua funcionando com suas tabelas e flag próprias. Com CRM habilitado, a sidebar evita os dois itens simultâneos e a rota antiga do funil direciona ao CRM; os dados `sales_*` continuam preservados.

## URLs do frontend

Substitua `1` pelo ID da conta:

- `/app/accounts/1/crm/dashboard`
- `/app/accounts/1/crm/leads`
- `/app/accounts/1/crm/deals`
- `/app/accounts/1/crm/funnel`
- `/app/accounts/1/crm/wallet`
- `/app/accounts/1/crm/activities`
- `/app/accounts/1/crm/calendar`
- `/app/accounts/1/crm/products`
- `/app/accounts/1/crm/proposals`

Endpoints públicos de proposta:

- `GET /api/v1/accounts/1/crm/public/proposals/:token`
- `POST /api/v1/accounts/1/crm/public/proposals/:token/view`
- `POST /api/v1/accounts/1/crm/public/proposals/:token/accept`
- `POST /api/v1/accounts/1/crm/public/proposals/:token/reject`

## Testes realmente executados

- ESLint em toda a árvore frontend do CRM, APIs e stores: passou sem erros.
- Vite build de produção: passou; 5.032 módulos transformados em 1m34s. Avisos preexistentes: `caniuse-lite` desatualizado, asset `/brand-assets/jrc-background.jpeg` resolvido em runtime e chunks grandes.
- Sintaxe Ruby em controllers, models, services, policies, serializers, jobs e migrations: passou.
- Boot Rails e listagem das rotas CRM: passou. As quatro rotas públicas foram conferidas no escopo `/api/v1/accounts/:account_id/crm/...`.
- `rails db:prepare` em PostgreSQL 16 efêmero: passou para as 17 migrations CRM e para a migration existente de Vendas. O teste real identificou e permitiu corrigir um nome de índice acima de 63 caracteres e uma coluna duplicada antes da entrega.
- 10 specs de models/services/policies: passaram, 10 exemplos e 0 falhas. Cobrem associação entre contas, perda obrigatória, mudança de etapa/auditoria, conversão de lead, policy de proprietário e importação Sales idempotente.
- 4 specs de request da API: passaram, 4 exemplos e 0 falhas. Cobrem feature flag desabilitada, contato sem telefone/e-mail, escopo de agente, visão administrativa e bloqueio de outra conta.
- Smoke test Node do composable real de drag-and-drop: passou, incluindo payload da mudança e limpeza do estado.

O spec Vitest do drag-and-drop foi criado na árvore reconhecida pelo projeto, mas o runner não chegou a coletá-lo porque a instalação de dependências compartilhada não contém `fake-indexeddb/auto/index.mjs`, importado pelo setup global. O comportamento foi coberto pelo smoke test direto e pelo build, mas não é declarado como Vitest aprovado. Não foram executados testes end-to-end no navegador nem testes manuais dos módulos legados listados nas pendências. Não foram executados deploy ou acesso a servidor de cliente.

## Rollback seguro

O rollback preferencial é desabilitar `jrc_crm`, pois é imediato, reversível e não toca nos dados. Não execute `db:rollback STEP=...` cegamente: a migration existente de Vendas possui timestamp posterior às migrations CRM e entraria na sequência de rollback. Para remover estruturas, use uma janela de manutenção, backup validado e uma migration reversa específica revisada para o ambiente; em incidentes com dados, restaure o backup.

## Roteiro local/LAB

1. Restaurar uma cópia anonimizada do banco no LAB.
2. Executar `bundle exec rails db:chatwoot_prepare`.
3. Iniciar Rails, Vite, PostgreSQL, Redis e Sidekiq pelo procedimento normal do JRC.
4. Habilitar `jrc_crm` somente na conta de teste.
5. Validar os nove URLs acima com agente e administrador.
6. Criar contato sem telefone/e-mail, lead, negócio vindo de conversa, atividade, produto e proposta.
7. Mover cards, perder com motivo, ganhar e conferir timeline/auditoria.
8. Validar retorno à conversa e os canais disponíveis nessa conversa.
9. Se houver Sales, executar a importação, comparar contagens/valores e repetir para confirmar idempotência.
10. Executar a regressão manual de login, conversas, canais, ramal, videoconferência, contatos e relatórios antes de promover.

Nenhum ZIP ou versão estável anterior foi sobrescrito.
