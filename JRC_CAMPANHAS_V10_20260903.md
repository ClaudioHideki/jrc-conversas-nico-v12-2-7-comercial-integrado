# JRC Campanhas V10 - 03/09/2026

## Objetivo

Evoluir o modulo JRC Campanhas existente para um disparador integrado ao proprio JRC Conversas, reutilizando Contatos, Etiquetas, Inboxes, CRM, Conversas, WhatsApp, Redis/Sidekiq e as regras reais dos provedores ja configurados.

## Principais entregas

- Tela principal de Disparos com criar, editar, iniciar, pausar, retomar, cancelar, duplicar, excluir e abrir relatorio.
- Botao Editar na listagem para campanhas em rascunho/agendadas.
- Botao de grafico abre o relatorio detalhado da campanha.
- Wizard em 4 etapas: Contatos, Configuracoes, Mensagens e Revisao.
- Publico por todos os contatos, etiquetas, Inbox de origem, CRM pipeline/etapas e lista sanitizada.
- Selecao de uma ou mais Inboxes WhatsApp de envio ja existentes no JRC.
- Rotacao round-robin, aleatoria e ponderada entre Inboxes.
- Intervalo minimo/maximo, janela de horario e dias permitidos.
- Modos de conversa: criar somente quando houver resposta, criar pendente ou criar aberta.
- Mensagens em sequencia: texto, template, imagem, documento, video e audio.
- Upload de midia e URL externa.
- Variaveis Liquid e spintax para texto.
- Overrides de mensagem/template por Inbox.
- Follow-up condicional quando nao houver resposta.
- Agendamento e recorrencia diaria, semanal, mensal ou por intervalo personalizado em dias.
- Blacklist por conta.
- Sanitizacao de listas CSV/coladas com validos, invalidos, duplicados e blacklist.
- Relatorio por campanha com enviados, entregues, lidos, respondidos, falhas e tabela por destinatario.
- Exportacao CSV do relatorio.
- Integracao de resposta com Conversas e acoes opcionais no CRM (etiqueta e mudanca de etapa).
- Status enviados/delivered/read/failed ligados aos webhooks WhatsApp existentes.

## Regras reais de WhatsApp

Esta versao nao simula envio. Ela reutiliza o provider da Inbox WhatsApp configurada no JRC.

- Mensagem livre/midia respeita a janela de atendimento existente no JRC/WhatsApp.
- Fora da janela, deve ser usado template aprovado quando exigido pela Meta/provedor.
- Credenciais, WABA, Phone Number ID e tokens continuam no backend/configuracao existente da Inbox.
- Nao existe token Meta hardcoded no frontend.

## Banco de dados

Nova migration:

`db/migrate/20260903193000_expand_jrc_campaigns_for_dispatcher.rb`

Ela expande `jrc_campaigns` e cria tabelas separadas para Inboxes da campanha, passos/mensagens, execucoes, destinatarios, entregas/status, eventos, blacklist, listas sanitizadas e midias.

Campanhas antigas com `message_body` recebem um primeiro passo de texto. Estados antigos de V9 que simulavam execucao/agendamento sao retornados para rascunho para revisao segura antes de novo disparo.

## Infraestrutura local

O pacote V10 mantem as portas validadas no ambiente local:

- Rails: 3011 -> 3000
- Vite: 3047 -> 3036
- PostgreSQL: 55453 -> 5432
- Redis: 56401 -> 6379
- Mailhog SMTP: 1036 -> 1025
- Mailhog Web: 8037 -> 8025

PostgreSQL e Redis usam `restart: 'no'` no compose local.

Nao houve alteracao de Gemfile, package.json ou Dockerfiles para a implementacao de Campanhas, portanto a intencao e reutilizar as imagens/dependencias existentes e evitar build completo quando o ambiente permitir.

## Antes de testar localmente

1. Preservar o backup V9 e o dump `chatwoot_dev` ja gerados.
2. Subir a V10 usando o mesmo projeto Docker/volumes da versao anterior, quando confirmado seguro.
3. Executar a nova migration antes de usar o modulo Campanhas.
4. Conferir a tela e criar primeiro uma campanha de teste controlada.
5. So realizar envio real com uma Inbox WhatsApp de teste corretamente configurada.

## Validacao feita no pacote

- Sintaxe Ruby dos arquivos alterados.
- Sintaxe JavaScript dos scripts Vue e API.
- JSON de i18n.
- Chaves estaticas de i18n usadas pela nova interface.
- Ausencia de marcadores de merge.
- Componentes novos sem CSS customizado/inline, usando as classes do design system/Tailwind do projeto.

O ambiente de empacotamento nao possui as dependencias Node/Ruby completas do projeto, portanto o build Vite/ESLint e a execucao real da migration devem ser validados no Docker local do JRC antes de considerar a versao aprovada para producao.

## Fora deste ciclo

- Rastreamento real de cliques em links nao foi inventado; so deve ser adicionado quando houver mecanismo de tracking real.
- A aba `Ligacoes` do Astra nao foi copiada, pois o JRC ja possui um modulo de Calling proprio e o comportamento exato daquela aba de referencia nao foi definido.
