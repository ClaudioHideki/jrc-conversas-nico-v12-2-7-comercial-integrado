# JRC Conversas NICO V12.2.8 — Quick/Full + Comercial Integrado

Base preservada: `jrc-conversas-nico-v12-2-7-comercial-integrado`.
Atualização incorporada: `JRC-Conversas-NICO-Quick-Full-Atualizado-20260910`.

## Estratégia

A atualização Quick/Full foi aplicada de forma seletiva sobre a base V12.2.7, sem substituir o projeto inteiro. Isso evita regressões nas funções comerciais, delegações, runtime do NICO e migration já presentes na versão validada.

## Atualizações Quick/Full incorporadas

- modo Quick do NICO ao abrir pelo launcher;
- expansão para modo Full;
- novo `JrcCopilotQuickPanel.vue`;
- novo `NicoComposer.vue`;
- novo `NicoInteractionStatus.vue`;
- novo estado de interação em `nicoInteractionState.js`;
- melhorias no fluxo de voz/transcrição/envio;
- ajustes de layout e convivência com widgets de chamada/SIP;
- novos testes de UI Quick e interação por voz;
- atualização da configuração Vitest do NICO;
- documentação `docs/NICO-QUICK-FULL-UX-20260910.md`.

## Comercial Integrado preservado

Foram mantidos, entre outros:

- `docker/nico-runtime.Dockerfile`;
- `db/migrate/20260910160000_add_nico_commercial_delegation.rb`;
- `app/services/jrc_nico/commercial_actions.rb`;
- `app/services/jrc_nico/delegated_actions.rb`;
- `app/jobs/jrc_nico/continue_command_job.rb`;
- specs do workflow/delegação comercial;
- comportamento comercial específico existente em `JrcCopilotPanel.vue`, incluindo autorização por delegação, formatação por campo e confirmação via `confirmAndExecute`.

## Observação de validação

O merge foi validado estaticamente para garantir que somente os arquivos da atualização Quick/Full foram modificados/adicionados em relação à base V12.2.7. O ambiente desta sessão não contém `node_modules`, portanto os testes Vitest/build completos devem ser executados no pipeline/local antes do deploy em produção.
