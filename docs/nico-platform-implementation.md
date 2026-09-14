# Implementação da plataforma NICO

Branch: codex/nico-platform-refactor. Base: 1409f1c.

## Em implementação

- Contexto de tela validado por catálogo e guia de Automações Inteligentes.
- Continuidade de pedidos compostos após leitura repetida.
- Ferramentas persistentes de atendimento: listar, criar desativada, ativar e pausar.
- Recibo explícito de delegação temporária, distinto de automação recorrente.
- Resumo de etapas baseado em comandos persistidos, com interrupção e sucesso parcial.
- Escopo por conta no job CRM, restrição de tipos e validação de ações do runner.
- Testes focados de regressão e isolamento executados; homologação integral continua pendente.

## Ainda pendente do plano aprovado

- Editor e eventos de automação CRM; schema e controller específicos.
- Recorrências por fuso, prazo, público, consentimento e condições de parada.
- Migração das demais ações comerciais do navegador para serviços backend.
- Análise paginada assíncrona de toda a base com evidências e checkpoints.
- Proposta com múltiplos destinos e recibos de entrega por canal.
- Guia completo de todos os módulos e revalidação granular de capacidades.
- Cliente 360, próximos passos, especialistas e indicadores reformulados.
- Provisionamento SaaS, planos, cotas, custos, observabilidade e recuperação.
- Homologação E2E dos cenários do relatório e publicação de imagens.

Esta lista registra andamento; não certifica conclusão ou implantação do plano.

## Validação desta etapa — 14/09/2026

- Runtime: 31 testes aprovados; TypeScript `tsc --noEmit` aprovado.
- `git diff --check`: aprovado.
- Seis cenários de regressão Rails adicionados, ainda não executados.
- Rails e integração: bloqueados pelo Docker Desktop local, cujo daemon Linux não inicia. Não foi feito reset nem remoção de volumes.
- Build e validação visual do frontend: pendentes.
- Nenhuma imagem desta branch publicada e nenhuma alteração aplicada ao servidor.

### Ambiente local iniciado

Docker voltou a responder. Em 14/09/2026 foi preparado o ambiente `jrc-nico-local` em http://localhost:3107, com banco dedicado, duas contas sintéticas e runtime em modo fixture (sem inferência externa). Build Vite concluído e login de administrador validado via HTTP 200. Serviços web, worker, runtime, PostgreSQL, Redis e gateway saudáveis. A validação visual pelo navegador automatizado não foi realizada porque a ferramenta não conseguiu inicializar. Os testes Rails continuam pendentes de execução.

Foram corrigidos no preparo local: volume de dependências usado pelo build frontend, criação dos diretórios log/tmp/storage e habilitação de automations nos dados de demonstração.

Para retomar, com o Docker funcionando, executar na raiz deste worktree:

```sh
docker compose -p jrc-nico-test -f docker-compose.nico-test.yml run --rm app bundle exec rspec spec/requests/jrc_nico_platform_spec.rb spec/requests/jrc_nico_json_reliability_spec.rb
```

Antes de disponibilizar automações CRM, ainda validar concorrência/idempotência, registro de falhas de condições e política de repetição do job. Os controles implementados aqui não certificam isolamento de todos os módulos do produto.

### Preparação da publicação — atualização posterior em 14/09/2026

- Correção de destinatário por nome, telefone/email e telefone ditado incorporada.
- Runtime: compilação e 31 testes aprovados; seis diagnósticos com contatos fictícios aprovados.
- Rails: execução de 22 exemplos; 21 passaram e um exigia a apresentação antiga de IDs.
  Essa expectativa foi atualizada para nome/telefone/canal e escolha por telefone;
  reexecução do cenário: um exemplo, zero falhas.
- Ambiente local reiniciado e login HTTP 200. Não houve chamada real de homologação.
- Workflow GHCR preparado para publicar app e runtime da mesma branch/commit.
  Instruções de instalação: `nico-platform-release.md`.
- Os registros anteriores de bloqueio Docker e testes pendentes são históricos,
  superados pelos resultados acima. Homologação completa do roadmap continua pendente.
