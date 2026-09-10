# NICO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Entregar NICO assistido integrado ao JRC Conversas e corrigir os controles necessários antes de liberar ações externas.

**Architecture:** Rails/Vue mantidos. Runtime elizaOS interno. Sidekiq executa tarefas persistidas; Rails decide autorização e aprovação.

**Tech Stack:** Ruby 3.4.4, Rails 7.1, Vue 3, PostgreSQL/pgvector, Redis/Sidekiq, runtime elizaOS TypeScript.

**Spec:** `docs/superpowers/specs/2026-09-07-nico-design.md`.

## Global Constraints

- Não usar `.env` recebido, credenciais de produção ou disparar mensagens reais.
- Preservar a cópia extraída e trabalhar somente em JRC-Conversas-NICO-dev.
- Rails permanece autoridade de conta, usuário e recurso.
- Sem envio público automático no copiloto inicial.
- Toda dependência externa não homologada aparece como pendência, sem sucesso simulado.
- Escrever testes de comportamento antes de alterar código, executar e registrar red/green.

## Etapa 1 Ambiente e baseline

- [x] Criar imagem de testes Ruby/Node e Compose isolado em `docker/nico-test.Dockerfile` e `docker-compose.nico-test.yml`.
- [x] Instalar dependências do lockfile em volumes exclusivos, sem ler secrets do ZIP.
- [x] Inicializar banco de testes com migrations e rodar suites CRM/Hodu existentes.
- [x] Registrar falhas preexistentes antes de modificar comportamento.

## Etapa 2 Campanhas governadas

Arquivos: controllers/models/services `jrc_campaigns`, policy, migration e specs correspondentes. Não editar arquivos NICO.

- [x] Escrever specs que bloqueiam membro comum no launch, inbox de outra conta, envio após blacklist e lançamento sem aprovação.
- [x] Executar specs e confirmar falhas pelas regras ausentes.
- [x] Adicionar autorização de administrador no backend para gestão/envio; preservar leitura apenas com permissão explícita.
- [x] Vincular aprovação a snapshot de público e conteúdo; alteração invalida aprovação; rollout bloqueia rascunhos sem aprovação.
- [x] Validar inbox legado e múltiplas inboxes por conta.
- [x] Serializar despacho por recipient/step; revalidar blacklist e opt-out; não reclassificar envio confirmado se sincronização posterior falhar.
- [ ] Expor ações de revisão/aprovação na interface de campanhas e testar fluxo. Código e 28 testes de backend concluídos; validação visual pendente.
- [x] Rodar specs e revisão do diff.

## Etapa 3 Runtime elizaOS

Arquivos: `services/nico-runtime/package.json`, lockfile, `src/*`, `test/*`, Dockerfile, README.

- [x] Verificar pacotes publicados e registrar versões compatíveis.
- [x] Testar health, token inválido, payload inválido, erro de modelo e evidência não autorizada.
- [x] Implementar `POST /v1/analyze` conforme contrato da spec usando runtime elizaOS real, com camada de provedor substituível em testes.
- [x] Remover qualquer dependência de ferramenta irrestrita, web browsing ou shell.
- [x] Testar contrato HTTP com servidor modelo de teste e registrar limite da prova.

## Etapa 4 Execução NICO em Rails

Arquivos: migration `create_jrc_nico_runs`, model `JrcNico::Run`, services ContextBuilder/RuntimeClient, job AnalyzeJob, controller account-scoped e rotas.

- [x] Testar criação/consulta restrita ao ator/conta, conversa não autorizada, limite de entrada, falha/cancelamento e atualização idempotente.
- [x] Criar execução persistida com estados queued/running/completed/failed/cancelled, request_id único, timestamps, entrada/saída limitadas e erro sanitizado.
- [x] Buscar conversa pela conta e policy de visibilidade; recuperar apenas CRM visível e conhecimento aprovado.
- [x] Chamar runtime interno com timeout; persistir resultado/uso e responder erro explicitamente.
- [x] Restringir feature às contas habilitadas; prover configuração de homologação documentada.

## Etapa 5 Painel e provedores

Arquivos: `JrcCopilotPanel.vue`, API JS e testes; serviços `jrc_ai` de uso/configuração.

- [x] Testar troca de conta/conversa, resposta tardia e evidências.
- [x] Integrar painel existente à execução NICO quando feature habilitada; preservar guia legado nas demais contas.
- [x] Exibir carregamento, falha, fonte e resposta sugerida sem envio público automático.
- [x] Garantir que limites cadastrados tenham enforcement onde usados; status de agentes deriva de execução real.

## Etapa 6 Ferramentas assistidas e conhecimento

- [x] Implementar contexto CRM com fonte e autorização; não duplicar cadastros.
- [x] Criar ingestão/revisão simples de conhecimento por conta, com revogação e busca autorizada.
- [x] Adicionar proposta de atividade CRM, aprovação humana e execução idempotente; demais ações externas ficam desabilitadas até contratos reais serem homologados.

## Etapa 7 Homologação e entrega

- [ ] Rodar testes Rails/Vue/runtime, build e diff check.
- [ ] Executar cenário integrado local com dois tenants e runtime real usando modelo de teste controlado.
- [ ] Testar backup/restauração e registrar comandos de rollback.
- [ ] Entregar runbook, variáveis necessárias, versão da imagem e pendências externas.
- [ ] Não afirmar WhatsApp/Hodu/provedor real homologados sem credenciais e evidências de execução.
