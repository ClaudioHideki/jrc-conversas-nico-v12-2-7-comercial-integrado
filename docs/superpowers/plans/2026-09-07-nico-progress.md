# Execução do plano NICO 2026-09-07

Plano: docs/superpowers/plans/2026-09-07-nico-implementation.md

Autorização: usuário pediu para estruturar plano recomendado e executar, após aceitar validação da arquitetura Rails/Vue com elizaOS interno.

Ruling: manter primeira liberação assistida e não enviar mensagens reais — preserva escopo e segurança descritos nos dois documentos.

Ruling: preparação de ambiente local é necessária; não usar .env do ZIP — evita conectar bancos e fornecedores desconhecidos.

Autorização adicional: usuário confirmou preparar ambiente local, sem conta GoPure/provedor existente.

Preparação concluída: cópia sanitizada, branch feature/nico-gopure, baseline fe112de; original extraído preservado. Imagem Ruby 3.4.4/Node 24.13.0 com gems fixadas construída; banco e dependências Vue em preparação.

Runtime: contrato validado por cinco testes, com red inicial por módulo ausente. Integração real elizaOS core/sql 1.7.2 + PGlite inicializou e executou useModel com plugin fixture explicitamente identificado (6 testes passaram). Fixture não representa inferência real. Compilação encontrou declarations extensionless do core; resolução Bundler verificada como correção. Teste HTTP adicionado, pendente execução.

Dependências runtime: auditoria inicial 11 findings. Overrides pdfjs-dist 6.2.108 e esbuild 0.25.12 aplicados; repetir auditoria e documentar riscos residuais. Não usar npm audit fix --force.

Rails: banco preparado. Red inicial comprovou campanhas index200/launch422/test_message422 para agente quando exigido403 e rotasNICO ausentes. Primeira suíte após fundação:53exemplos,21falhas;9request NICO+3contexto+4jobs+1cliente passaram;6request campanhas e9referências CRM/Hodu passaram. Duas falhas cliente são identidade de classe após reload (mesmo nome, exceção correta); testes ajustados conforme AGENTS.md. Dezessete falhas de serviços campanhas por callback de provisionamento360dialog bloqueado pelo WebMock; agente corrige apenas fixture antes de provar red de despacho. Duas falhas de conhecimento eram rotas ainda ausentes; implementação agora adicionada. JSON: tmp/nico-stage1-results.json.

Interface: sessão NICO com conta explícita, descarte de respostas após navegação e idempotência de retry passou3testes Vitest. Painel integrado à conversa e base de documentos com aprovação explícita implementados, aguardam validação conjunta/build/browser.

Runtime: build TypeScript passou e7testes passaram, incluindo API HTTP autenticada/limites/escopo e elizaOS real com fixture. Auditoria após override PDF:0high/critical,5moderate+5low. Override esbuild ainda não substituiu subárvore antiga; lock/instalação precisam reconciliação antes da entrega. Não declarar correção desse advisory.

Ambiente: pnpm instalado em volumeLinux após ENOMEM no cache em filesystemWindows. CacheBootsnap agora em volumeLinux persistente. app usa DB jrc_nico_test (agente campanhas); app_root usa DB jrc_nico_root_test (NICO). Ambiente de homologação definido em docker-compose.nico-local.yml, credenciais aleatórias em local/nico.env (ignorado peloGit), ainda não iniciado/semeado.

Produção: framework-readiness.md confirma Rails7.1 sem suporte. Modernização para linha suportada com resolução das gems incompatíveis é pré-requisito de publicação; ambiente local não significa aprovação para produção.

Pendências: recuperação fila, quotas, proposta/aprovação de atividade CRM, sementes, procedimento de início/backup, e2e navegador e revisão final. Testes de recuperação/propostas escritos, aguardam red no DB separado.

Revisão: campanhas28/28green; runtime9/9green+build, logsSDKsilenciados/cancelamentotransporte/tokensconsistentes. HistóricoRed3/2falhas confirmouCRMrevogado; fonte_manifest+ResultAccess corrigidos e revisados. Contabilizaçãoaccount→runlock elimina corrida. Migração130000 aplicada rootDB e homol. Suíte integrada em andamento tmp/nico-final-suite.json. Homol semeou2admins; frontenddevENOMEM real, mudando para buildestático public/vite-dev com gatewaylocalhost3107 semcredenciais. Startup/backup scripts criados+parser/mocktestados; execução real backup/e2e ainda pendentes. Baselineaudits: Ruby2advisories(ActiveStorageCVE2026-66066 requerRails>=7.2.3.2, mail2.8.1); Brakeman5.4.1 37warnings/6parseerrors, scannerlimitado. JSauditbaseline70ocorrências; agenteaplicapatchescompatíveis antesbuild. Runtime6lowdeelliptic apenas,0moderate/high/critical. Usuáriopriorizouabrirlocal, credenciais e entenderpainelNico emWhatsApp/Instagram; esclarecidoIArealexigeprovedor, canaiscontinuamnoJRC.

Regressão integrada final62/62 passou via scripts/nico-specs.rb (sem hot-reload; autenticação, callbacks e policies ativos), 3m57s+44sboot. Execução anteriorcomreloadfoiinterrompida35exemplos/1falha500durantearquivosanotados; casoisoladoecompletorepetidopassaram. Prodpnpmaudit0vulnerabilidadesapóspatchescompatíveis (Vite6.4.3, semmajorupgrade). Buildfrontendestático aindaemexecução; não afirmarUIpronta. Seedatendenteconcorreucombuild e falhouENOMEMreaddir;repetirseedapósbuild. Localdevagoracache_classesJRC_NICO_LOCAL_STATIC=true elimina filesystemhotreload (requere reinício apóseditarRuby).

Nova tentativa de frontend: heap 2048 MiB falhou com V8 heap OOM após 5073 módulos. Tentativa com 2816 MiB e minify=false chegou a rendering chunks; Docker passou a retornar HTTP 500 e não produziu public/vite-dev. Cliente de build interrompido. Backup real falhou antes de pg_dump devido ao Docker indisponível. Reinício normal inicialmente excedeu prazo; stop --force depois informou já parado. Reinício do Docker em andamento. Host tem aproximadamente 8 GiB de RAM, com cerca de 1,1 GiB livre na consulta. E2E/UI/backup continuam pendentes. Credenciais locais confirmadas em local/nico.env, sem chave OpenAI ativa.

Homologação real local: primeiro build em volume Linux concluído em 9m11s, manifesto copiado. Login visual e login API passaram. Teste scripts/nico-local-smoke.mjs passou com duas contas, runtime fixture, isolamento, restrições do atendente, proposta/aprovação idempotente CRM e nenhuma mensagem pública nova (docs/validation/local-smoke-20260907.json). Backup pg_dump concluído. Correções operacionais: Tidewave não carregado no modo local estático; painel normaliza conversation_id e conversationId. Segunda compilação inclui normalização de rotas; UI final com capturas ainda em validação. Containers baseline/jrc-phase1-demo temporariamente parados por autorização para liberar memória e devem ser restaurados ao final.

A validação visual reproduziu 401 nos três adapters NICO: importavam o singleton axios sem a sessão do JRC, enquanto o sistema usa window.axios criado por createAxios. Teste de regressão RED: três falhas Unauthenticated client. Correção segue cliente global padrão; GREEN: 6/6 testes. Nova compilação auth em andamento, com web/gateway mantidos ativos e worker/runtime mais baseline temporariamente parados. A UI ainda não está homologada até repetir teste visual. Backup restaurado com sucesso em banco separado, com duas contas; banco da aplicação preservado.

Estado em 07/09/2026: compilação autenticada publicada. UI E2E passou (run 5): login, rotas principal/Participantes, análise fixture e aprovação humana CRM, sem erros JavaScript. Evidências em nico-ui-local.json e capturas nico-*.png. Containers baseline e phase1-demo restaurados. Inicialização local remove PID obsoleto antes do Rails. Transferência: código/artefatos, quatro imagens Docker, dependências, Redis/PGlite e SQL exportados; cinco arquivos gzip íntegros. SQL final restaurado em banco isolado: 2 contas, 3 usuários, 5 runs. Sintaxe PowerShell e Compose de transferência passaram; execução em segundo computador não realizada. Broker Incrementos 1/2 inspecionados: integração viável por adaptador, mas envio/recebimento e webhooks completos ausentes. Relatório INTEGRACAO-BROKER.md. Pacote destinado apenas à homologação fixture.
