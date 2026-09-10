# Especialistas JRC — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Permitir executar os sete especialistas na conversa com contexto autorizado e ações locais aprovadas.

**Architecture:** Preservar Rails como autoridade sobre conta, contexto, consumo e efeitos. O runtime elizaOS despacha análises especializadas com perfis fixos; a interface seleciona o especialista e apresenta suas limitações. Não ativar envio automático nem apresentar operações externas sem integração como concluídas.

**Tech Stack:** Rails/Vue existentes, elizaOS 1.7.2, OpenAI gpt-4.1-mini, PostgreSQL, Sidekiq.

**Spec:** docs/VALIDACAO-AGENTES-JRC-20260908.md e autorização de implementação de 08/09.

## Restrições

- Continuar a implementação na cópia de desenvolvimento e branch feature/nico-gopure, preservando alterações anteriores.
- Nenhuma credencial em código, relatórios ou ZIP.
- Escopo inicial assistido; fontes externas de ERP, chamados e PABX dependem de identificação pelo usuário.
- Não confundir análise de CX com indicador de churn medido, tarefa CRM com ticket externo, nem checklist sugerido com provisionamento.

## 1. Execução especializada e governança

Files: services/nico-runtime/src/agents.ts, contract.ts, engine.ts; app/services/jrc_nico/agent_catalog.rb; app/models/jrc_nico/run.rb; runs_controller.rb; runtime_client.rb; analyze_job.rb; migration 20260908100000.

- [x] Testar contrato aceitando sete chaves e rejeitando nomes arbitrários; confirmar falha antes da implementação.
- [x] Persistir agent_key com default nico, incluir no fingerprint e no consumo; preservar fingerprint legado para NICO.
- [x] Catálogo com nome, descrição, limitações e ferramentas permitidas. Perfis fixos no runtime, sem aceitar instruções de sistema do cliente.
- [x] Testar conflito de idempotência quando muda agente, rejeição de agente desconhecido e permissão por conta.

Contrato: `Run.fingerprint_for(conversation_id, message, agent_key = 'nico')`; API create recebe `agent_key`, snapshot devolve chave. Limite mensal agrega todas as execuções desta plataforma.

## 2. Conversa e catálogo

Files: NicoConversationPanel.vue, nicoRunSession.js, jrcNico.js, JrcAiAgentsPage.vue, cockpit_metrics_service.rb, en/jrcNico.json.

- [x] API de catálogo autenticada e seleção na conversa; trocar agente mantém isolamento de requisições e não cancela silenciosamente trabalho já admitido.
- [x] Mostrar o agente responsável pelo resultado e limitações explícitas do perfil.
- [x] Remover encaminhamento dos cartões para o copiloto genérico legado.
- [ ] Verificar envio de agent_key na sessão e compilar a interface uma vez após alterações.

## 3. Ações locais após revisão

Files: proposals_controller.rb, proposal.rb, NicoProposalPanel.vue; spec/requests/jrc_nico_proposals_spec.rb.

- [x] Comercial: criar oportunidade vinculada ao lead/conversa com chave de conversão idempotente, usando o funil existente após aprovação.
- [x] Demais especialistas: permitir atividade de acompanhamento ou tarefa interna, identificando agente e execução na auditoria; nenhuma alegação de ticket externo.
- [x] Revalidar fontes/permissões na aprovação e rejeitar ações não permitidas ao perfil.
- [x] Testar repetição da aprovação, agente sem ferramenta e acesso revogado.

## 4. Homologação e limites de entrega

- [x] Migrar bancos de teste e homologação, executar testes Ruby/runtime/frontend e verificar logs sem dados sensíveis.
- [ ] Executar análise real de especialista na conta sintética 1; verificar mensagens públicas inalteradas.
- [ ] Verificar interface compilada, registrar evidências e atualizar matriz com funcionalidades reais.
- [x] Documentar pendências externas: ERP/segunda via/negociação/agendamento de cobrança; API de tickets; portabilidade/PABX; NPS/jornada; canais reais; automação entre agentes e supervisor global.

As pendências externas não serão substituídas por respostas simuladas. Esta entrega assistida constitui uma etapa operacional do projeto, não o MVP integral dos DOCX.

