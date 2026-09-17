# JRC Conversas + Broker: versão candidata de 17/09/2026

## Escopo decidido pelo usuário

O cliente utiliza o JRC Conversas da JRC. O editor e o motor Flows ficam no JRC; o Broker transporta WhatsApp, gerencia instâncias e mantém o vínculo da caixa API. Não é necessário instalar Typebot ou n8n.

O administrador configura credenciais, cria/importa fluxos, testa e ativa nas caixas. O agente acompanha os flows das caixas às quais pertence e usa a reconexão WhatsApp apenas com concessão administrativa. Credenciais, definições completas e mudanças de automação continuam restritas ao administrador.

Integrações com Chatwoot de terceiros e o portal externo de Flows são beta. Estão desligados por padrão. O canvas React experimental da branch separada do Broker não entra nesta versão.

## Consolidação

- GitHub JRC main observado: `62c14af`.
- Base local integrada: `f49c82d`, contendo 11 commits posteriores ao main, inclusive Nico e integração nativa Broker.
- Fontes Flows: laboratório local de 16/09, incorporados por comparação de três versões com o ZIP original. Preservados menu/rotas do Broker e atualizações do Nico.
- Não foram incorporadas exceções locais do SafeFetch, senhas, volumes, JSONs de clientes, certificados ou dados do laboratório.
- Broker consolidado em branch própria, a partir de `origin/main a16c1cd`, com os 13 commits locais até `ce878f8`. Os nove commits do GitHub que atualizam o Compose foram preservados.

## Trabalho e verificação desta versão

1. Consolidar o módulo Flows e integração nativa sem substituir o restante do JRC.
2. Habilitação global/por conta; acompanhamento por agentes; beta externo desabilitado.
3. Preparar app Rails, Nico runtime e sandbox como imagens versionadas; manter API/web/worker do Broker.
4. Verificar migrações, permissões, execução nativa, sandbox, frontend e contratos Broker.
5. Entregar procedimento Dokploy com backup, migração, ativação por conta e rollback.

O resultado da validação e os comandos de instalação são registrados em `docs/DEPLOY-FLOWS-BROKER.md`. Preparação local não significa publicação no GitHub/GHCR nem atualização do servidor.
