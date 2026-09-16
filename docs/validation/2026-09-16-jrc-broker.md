# Execução local — integração nativa JRC Broker

Branch `codex/jrc-broker-native`, worktree isolado `jrc-broker-native-20260916`.
HEAD de partida `f38fe020057277cf5d2733460915e67451898165`; baseline do pacote
`62c14af884c7f45fa640345556f2ffecc22113d8`. Os cinco commits posteriores e o outro
checkout com `db/schema.rb` modificado foram preservados. Broker plano 01 concluído
localmente até `eeb3b38`, incluindo OpenAPI regenerado depois do commit sem diff.

Sem push, merge, publicação, deploy, credenciais remotas ou números reais.
Planos 02 e 03 não estão concluídos. Piloto remoto depende de autorização separada.

## Ambiente

- Ruby 3.4.4 / Bundler 2.5.16 da imagem local de laboratório `jrc-nico-test:local`.
- PostgreSQL pgvector e Redis novos, rede interna `jrc-native-validation-20260916`;
  banco exclusivo `jrc_broker_native_test`, porta local 55434; Redis 16381.
- Pool automático de redes Docker estava esgotado; sub-rede interna 10.246.117.0/24
  escolhida após listar as redes existentes e conferir ausência de sobreposição.
- Bind mount Windows demorou vários minutos no boot. A primeira execução foi
  interrompida, sem evidência de migração concluída. Substituída por `git archive HEAD`
  extraído em `/workspace` de container exclusivo, com overlay dos arquivos alterados.
  Apenas código rastreado/arquivos novos desta tarefa são copiados; nenhum `.env` real.
  Script/logs locais em `.codex/`, ignorados. Schema baseline carregado com exit 0.
- O schema gerado voltou ao worktree e o diff contém somente as três tabelas J1,
  seu índice/FKs e a versão nova. Nenhum dado produtivo foi utilizado.

## J1 — configuração cifrada e vínculos

Migração `20260916163000_create_jrc_broker_integration_tables.rb` aplicada no banco
descartável com exit 0. Tabelas por conta: configuração, vínculo de inbox e grants.
FKs compostas impedem inbox de outra conta e exigem associação vigente em account_users
e inbox_members; exclusão da associação elimina o grant. Canais existentes preservados.

AES-256-GCM com purpose por conta e chave dedicada de 32 bytes. Serialização padrão
mostra somente `configured`/`has_credential`; inspeção e filtros ocultam a cifra.
Configuração só é salva depois de conferir contexto autenticado, organização, conta,
origem Chatwoot e revisão. A chamada HTTP ocorre antes de abrir o lock da conta.
Origem Broker deve estar na lista administrativa exata. Feature desligada não exige
a nova chave; habilitada com chave ausente/inválida falha fechada.

RED real: três constantes ainda inexistentes no carregamento RSpec. GREEN: 7 exemplos,
0 falhas. Regressão com InboxPolicy e Inbox: **72 exemplos, 0 falhas**, exit 0.
RuboCop: sete arquivos, ajustes de complexidade/formatação concluídos, exit 0.
Avisos preexistentes Rails 7.1/dependências foram registrados, sem atualização em lote.
Logs locais: `.codex/j1-red.log`, `j1-green.log`, `j1-regression.log`, `j1-lint.log`.

## Configuração e rotação (procedimento; não executado em servidor)

Definir `JRC_BROKER_ALLOWED_ORIGINS` com origens HTTPS canônicas exatas do Broker,
`FRONTEND_URL` com a origem desta instalação e `JRC_BROKER_CREDENTIAL_KEY` no cofre.
A chave é base64 estrito de 32 bytes; não usar SECRET_KEY_BASE como fallback.
Manter `JRC_BROKER_ENABLED=false` até terminar o gate do plano 02.

Backup deve incluir dados e chave dedicada no cofre privado. Para trocar a chave:
em manutenção controlada, ler os registros com a chave antiga, recifrar com a nova
usando o mesmo contexto por conta, validar leitura, e só então trocar o ambiente.
Conservar backup recuperável com a chave anterior até testar restauração. Não basta
alterar a variável, pois isso tornaria as credenciais existentes ilegíveis.
