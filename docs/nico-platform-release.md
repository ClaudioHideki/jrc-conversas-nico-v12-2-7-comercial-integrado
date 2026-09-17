# Publicação NICO Platform — 14/09/2026

> Histórico da entrega Nico de 14/09. Para a release conjunta JRC + Flows + Broker de 17/09, os workflows e as tags foram atualizados; siga [DEPLOY-FLOWS-BROKER.md](DEPLOY-FLOWS-BROKER.md).

O workflow `build-ghcr.yml` publica os dois componentes da branch
`codex/nico-platform-refactor`, usando o mesmo commit.

## Imagens

- Rails e Sidekiq: `ghcr.io/claudiohideki/jrc-conversas-nico-v12-2-7-comercial-integrado:4.16.2-jrc-nico-platform-20260914`
- Runtime: `ghcr.io/claudiohideki/jrc-conversas-nico-v12-2-7-comercial-integrado-nico-runtime:4.16.2-jrc-nico-platform-20260914`

Cada build também publica `sha-<7 primeiros caracteres do commit>`.
Prefira essa tag específica para instalar e registrar a versão no Dokploy.
Espere os dois jobs concluírem com sucesso antes do deploy.

## Instalação no Dokploy

1. No Compose do LAB, atualize `image` de Rails e Sidekiq para a mesma imagem de app.
2. No serviço separado NICO runtime, use Provider Docker e a imagem de runtime do mesmo commit.
3. Preserve volumes, banco, Redis, redes, domínios e variáveis existentes.
   O ambiente local de demonstração usa fixture: não copie suas variáveis para o servidor.
4. Faça deploy do runtime e depois do app/Sidekiq.
5. Confira os logs, `/health` do runtime a partir do Rails e faça uma consulta de contatos no NICO.
6. Valide a escolha por telefone entre contatos homônimos antes de autorizar uma ação real.

Este conjunto de alterações não adiciona migrações ao banco.
Para reverter, use as tags anteriores dos dois componentes e faça novo deploy.

## Escopo

- Reconhecimento de destinatário por nome, telefone, email e o formato ditado validado.
- Contexto da tela no copiloto e resumo persistido de etapas.
- Continuidade de consultas em pedidos compostos.
- Ferramentas para consultar, criar desativada, ativar e pausar regras de atendimento.
- Restrições de conta e ações no executor de automação CRM.
- Ajustes no ambiente de testes local.

Não representa a conclusão de todo o roadmap de plataforma/multitenancy.
As pendências funcionais estão em `nico-platform-implementation.md`.
