# JRC V11 — Campanhas Premium UX

## Base preservada

- Base exclusiva: `JRC-CAMPANHAS-LAYOUT-V10-CAMPANHAS-COMPLETO-CRM-RELATORIOS-20260903(3).zip`.
- O ZIP V10 original foi mantido intacto e validado com `unzip -t`.
- Não serão alterados banco, migrations, Redis, `.env`, Docker, CRM, Relatórios globais, Conversas, Configurações, usuários, permissões ou integrações.

## Inventário pré-edição

Arquivos existentes de Campanhas previstos para alteração:

- `app/javascript/dashboard/routes/dashboard/jrcCampaigns/JrcCampaignsPage.vue`
- `app/javascript/dashboard/routes/dashboard/jrcCampaigns/components/CampaignWizard.vue`
- `app/javascript/dashboard/api/jrcCampaigns.js`
- `app/javascript/dashboard/i18n/locale/en/jrcCampaigns.json`
- `app/controllers/api/v1/accounts/jrc_campaigns/campaigns_controller.rb`
- `app/controllers/api/v1/accounts/jrc_campaigns/metadata_controller.rb`
- `app/models/jrc_campaigns/campaign.rb`
- `app/services/jrc_campaigns/audience_resolver.rb`
- `app/services/jrc_campaigns/rotation_selector.rb`
- `config/routes.rb` (somente rotas exclusivas de `jrc_campaigns`)

Arquivos novos, todos exclusivos de Campanhas:

- `app/javascript/dashboard/routes/dashboard/jrcCampaigns/components/CampaignPerformanceChart.vue`
- `app/services/jrc_campaigns/dashboard_service.rb`
- `app/services/jrc_campaigns/test_message_service.rb`

## Critérios de implementação

- Todos os indicadores e previews usam dados retornados pelo backend; nenhum número ilustrativo da referência visual é inserido no produto.
- O schema atual será reutilizado, sem migration.
- Modos legados de distribuição permanecem válidos para campanhas existentes.
- A Configuração global da sidebar permanece intocada.

## Validações finais

- Integridade do V10 original: `unzip -t` concluído sem erros.
- SHA-256 do V10 original: `ba212102fc5a7ed0b485ca724f466d5a9d527b4f5a477c4140a4f744c40a63bc`.
- Frontend: ESLint concluído com código de saída 0 e zero erros nos quatro arquivos JavaScript/Vue alterados ou criados.
- Componentes Vue: parsing e `compileScript` concluídos nos três componentes de Campanhas.
- Traduções: JSON válido e todas as chaves literais `JRC_CAMPAIGNS` referenciadas foram encontradas.
- Build de produção: Vite concluiu a transformação de 5.060 módulos e gerou o bundle de Campanhas.
- Backend: os oito arquivos Ruby alterados ou criados, incluindo `config/routes.rb`, foram validados por parser Ruby sem erro sintático.
- Estrutura: os arquivos essenciais de Rails, Vue, PostgreSQL, Redis e Docker permanecem presentes; nenhuma migration foi adicionada.
- Auditoria SHA-256 contra 10.346 arquivos da base: nenhum arquivo original foi removido. O diff de código-fonte ficou restrito aos dez arquivos existentes inventariados e aos quatro arquivos novos exclusivos de Campanhas.
- Proteção de escopo: zero alterações em `.env`, `database.yml`, Redis, Docker, CRM, Relatórios globais, Conversas, Configurações da sidebar, PABX, WhatsApp Calling, usuários, permissões e integrações.
- Assets: `public/vite` foi recompilado para incluir a V11; os arquivos versionados anteriores foram preservados.

O ambiente de validação não contém executável Ruby/Bundler, portanto não foi possível iniciar Rails nem executar RSpec. Essa limitação foi compensada com parsing sintático de todos os arquivos Ruby do diff e validação integral do build do frontend.
