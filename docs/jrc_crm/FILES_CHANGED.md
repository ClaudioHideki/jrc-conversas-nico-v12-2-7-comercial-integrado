# Inventário de arquivos

Comparação feita contra `jrcconversas-kanban-vendas-mvp-v2-20260824.zip`, excluindo artefatos de build, logs, cache e `node_modules`.

## Criados — 171 arquivos, incluindo esta documentação

- `app/controllers/api/v1/accounts/crm/`: 22 controllers.
- `app/models/jrc_crm/`: 25 models.
- `app/services/jrc_crm/`: 15 services.
- `app/policies/jrc_crm/`: 4 policies.
- `app/serializers/jrc_crm/`: 8 serializers.
- `app/jobs/jrc_crm/`: 5 jobs.
- `app/javascript/dashboard/api/crm/`: 20 clientes de API e índice.
- `app/javascript/dashboard/store/crm/`: store raiz e 7 módulos.
- `app/javascript/dashboard/routes/dashboard/crm/`: layout, rotas, 5 composables/componentes compartilhados, Kanban, widget de conversa e views.
- `app/javascript/dashboard/i18n/locale/en/crm.json`.
- `db/migrate/20260824000001_...` até `20260824000017_...`.
- `lib/tasks/jrc_crm.rake`.
- `spec/factories/jrc_crm_factories.rb`.
- `spec/models/jrc_crm/deal_spec.rb`.
- `spec/policies/jrc_crm/crm_policy_spec.rb`.
- `spec/requests/api/v1/accounts/crm/deals_spec.rb`.
- `spec/services/jrc_crm/deal_pipeline_service_spec.rb`.
- `spec/services/jrc_crm/lead_conversion_service_spec.rb`.
- `spec/services/jrc_crm/sales_import_service_spec.rb`.
- `app/javascript/dashboard/routes/dashboard/crm/composables/spec/useDragAndDrop.spec.js`.
- `docs/jrc_crm/INTEGRATION_REPORT.md` e `docs/jrc_crm/FILES_CHANGED.md`.

Alguns arquivos avançados estão presentes como arquitetura não registrada em rotas; o relatório de integração identifica explicitamente quais não estão prontos.

## Alterados — 14 arquivos do projeto-base

- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`
- `app/javascript/dashboard/components/widgets/conversation/ConversationSidebar.vue`
- `app/javascript/dashboard/featureFlags.js`
- `app/javascript/dashboard/i18n/locale/en/index.js`
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`
- `app/javascript/dashboard/routes/dashboard/sales/routes.js`
- `app/javascript/dashboard/store/index.js`
- `app/models/account.rb`
- `app/models/contact.rb`
- `app/models/conversation.rb`
- `config/features.yml`
- `config/routes.rb`
- `config/sidekiq.yml`
- `db/schema.rb`

## Migrations adicionadas

1. `20260824000001_create_jrc_crm_pipelines_and_stages.rb`
2. `20260824000002_create_jrc_crm_lost_reasons.rb`
3. `20260824000003_create_jrc_crm_leads.rb`
4. `20260824000004_create_jrc_crm_deals.rb`
5. `20260824000005_create_jrc_crm_deal_contacts.rb`
6. `20260824000006_create_jrc_crm_products.rb`
7. `20260824000007_create_jrc_crm_deal_products.rb`
8. `20260824000008_create_jrc_crm_proposals.rb`
9. `20260824000009_create_jrc_crm_activities_and_follow_ups.rb`
10. `20260824000010_create_jrc_crm_audit_events.rb`
11. `20260824000011_create_jrc_crm_automations.rb`
12. `20260824000012_create_jrc_crm_import_batches.rb`
13. `20260824000013_create_jrc_crm_campaigns_and_custom_attributes.rb`
14. `20260824000014_create_jrc_crm_organizations.rb`
15. `20260824000015_create_jrc_crm_deal_conversations.rb`
16. `20260824000016_add_jrc_crm_integrity_constraints.rb`
17. `20260824000017_add_legacy_sales_references_to_jrc_crm.rb`
