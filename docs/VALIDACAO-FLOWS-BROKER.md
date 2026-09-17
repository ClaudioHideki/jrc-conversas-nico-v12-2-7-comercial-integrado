# Validação do candidato JRC + Broker — 17/09/2026

Escopo: módulo Flows nativo no JRC, integração Broker existente e habilitação por conta/perfil. A revisão candidata fica separada do main; não houve publicação de imagens no GHCR nem alteração do servidor.

## Resultados locais

| Verificação | Resultado |
| --- | --- |
| Migrações Flows no PostgreSQL isolado | 3 migrações aplicadas; schema consolidado com as tabelas Broker existentes |
| Backend JRC Flows + Broker | 40 exemplos distintos aprovados: execução inicial com 38/38 e nova execução dos 7 testes Flows após acrescentar 2 casos de JSON |
| Interface Broker dentro do JRC | 23/23 testes aprovados |
| Interface Flows por perfil e troca de conta | 3/3 testes aprovados |
| Frontend completo JRC | Build Vite de produção aprovado: 5.111 módulos, incluindo Flows e Broker |
| Sandbox JavaScript em container sem rede | 5/5 testes aprovados |
| Broker: integração PostgreSQL | 25/25 testes aprovados (controle, autorização, estado, provisionamento e isolamento entre organizações) |
| Broker: interface de conexão ajustada | 7/7 testes aprovados |
| Overlay JRC | Compose renderizado com valores fictícios: preserva banco, volume e rede de entrada; sandbox privado sem portas publicadas |
| Compose Broker | Renderização aprovada com valores fictícios; credenciais da plataforma somente na API |
| Suíte completa Broker | 1.078/1.078 testes aprovados, sem falhas |
| Imagens locais | Cinco imagens concluídas: aplicação JRC, sandbox, Nico runtime e API/web Broker |
| Imagem final JRC sem rede e somente leitura | gRPC 1.72.0 e cliente PostgreSQL carregados; manifesto dos assets, backend Flows e entrypoint executável sem CRLF confirmados |

Foi corrigida uma falha encontrada no cancelamento de entrega: a associação da conversa recém-criada podia carregar `display_id` alterado em memória. O serviço agora consulta o registro persistido antes de adquirir o bloqueio, sem alterar a associação do chamador. A revogação da funcionalidade cancela o envio pendente.

As negações da API Flows usam o contrato existente do JRC (401 para autorização recusada pelo Pundit); a API Broker tem o próprio contrato 403. A suíte verifica o bloqueio, não apenas o desaparecimento do menu. Respostas Flows usam `Cache-Control: no-store`.

O teste nativo percorre mensagem → captura → mensagem personalizada → conclusão, com registros persistidos. JSON nativo com BOM é reimportado, credenciais protegidas são excluídas da exportação e subworkflow ausente impede ativação. O portal/eventos externos retornam 404 com beta desligado.

No primeiro build local, a compilação de dependências gRPC ficou sem avanço visível por tempo prolongado no Docker de 6 CPUs/5,7 GiB. O build foi reiniciado com `GRPC_RUBY_BUILD_PROCS=2`. A compilação Vite separada atingiu o limite padrão do Node no Windows e foi repetida com `NODE_OPTIONS=--max-old-space-size=4096`, o mesmo valor do Dockerfile. Não houve alteração das verificações funcionais para contornar essas limitações.

O segundo build Docker da aplicação terminou com sucesso, incluindo instalação das gems, SDK, assets de produção e empacotamento. A camada de dependências Ruby levou aproximadamente 56 minutos neste primeiro build sem cache; a etapa de assets levou cerca de 3 minutos e 23 segundos. A imagem local é `jrc-conversas:flows-broker-release-20260917`, identificador `03f16f780171`. Isso não é uma imagem publicada no GHCR: a publicação deve usar o workflow e a tag do commit revisado, conforme o guia de implantação.

O build do runtime Nico informou 6 vulnerabilidades de severidade baixa nas dependências existentes; não foi aplicado `npm audit fix --force` nem atualização incompatível nesta consolidação. O build Broker informou zero vulnerabilidades, e a inspeção dos 11 arquivos de assets da imagem web não encontrou segredos ou módulos de servidor. O submódulo Evolution e o submódulo aninhado foram confirmados nos commits fixados pelo projeto.

## Reprodução

- Rails, usando um banco **exclusivo de teste**, com schema/migrações preparados:
  `bundle exec rspec spec/requests/api/v1/accounts/jrc_flows_spec.rb spec/requests/api/v1/accounts/jrc_broker_spec.rb spec/requests/api/v1/accounts/jrc_broker_inbox_spec.rb spec/requests/api/v1/accounts/jrc_broker_contract_spec.rb spec/services/jrc_broker spec/models/jrc_broker_integration_spec.rb spec/jobs/jrc_broker_webhook_job_spec.rb`
- Vue: `pnpm exec vitest run app/javascript/dashboard/components-next/jrc-broker/__tests__ app/javascript/dashboard/routes/dashboard/jrcFlows/__tests__ --minWorkers=1 --maxWorkers=2`.
- Sandbox: construir `services/flows-sandbox`, executar `node --test sandbox.test.mjs` no container com `--network none --read-only --cap-drop ALL`.
- Broker: instruções e resultados complementares em `docs/validation/2026-09-17-jrc-release.md` no repositório Broker.
- Imagem JRC: `docker build -f docker/Dockerfile --build-arg GIT_SHA=local-validation -t jrc-conversas:flows-broker-release-20260917 .`. Para verificar as dependências nativas sem rede: `docker run --rm --network none --read-only --entrypoint bundle jrc-conversas:flows-broker-release-20260917 exec ruby -rgrpc -rpg -e 'puts GRPC::VERSION; puts PG.library_version'`.

## Limites do aceite

Não foram exercitados número real de WhatsApp, chamadas OpenAI pagas, e-mail, Instagram/Facebook nem URA/ramais. O JADE completo continua dependente das credenciais e dos subworkflows BTV/KSYS. A validação isolada não comprova configuração do servidor, latência de produção, todos os nós possíveis do n8n ou compatibilidade universal de importação.

As interfaces foram verificadas por testes de componentes e build; o roteiro de aceite visual e entrega real no servidor está em [DEPLOY-FLOWS-BROKER.md](DEPLOY-FLOWS-BROKER.md). Os containers de banco usados nesta tarefa são separados das instalações do laboratório e foram desligados após os testes.

O laboratório original da porta 3116 foi reaberto com seus containers, volumes e configurações existentes; `/app/login` respondeu HTTP 200. Ele preserva o código anterior do laboratório. O candidato consolidado desta release está nas branches de revisão e nas imagens locais, não foi aplicado automaticamente sobre aquela instalação.
