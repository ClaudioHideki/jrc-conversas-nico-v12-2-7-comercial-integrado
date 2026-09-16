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

## J2 — controle autenticado por conta e inbox

Endpoints `/api/v1/accounts/:account_id/jrc_broker`: configuração GET/PATCH,
resources, listagem/criação/consulta/recuperação de onboarding e, por inbox,
status, pair, disconnect, confirm_identity, agents e grants. Feature global e flag
da conta obrigatórias. Admin configura/cria/desconecta/confirma; agente precisa
estar na inbox e ter concessão explícita para reconectar uma identidade já aprovada.
Status filtra ações; remoção da associação elimina o grant. Revogação durante HTTP
também impede a entrega do QR. Conta/ator são derivados da sessão no servidor.

HTTP server-side HTTPS verificado, sem proxy ambiente/redirect/retry de mutação,
timeouts e limite de corpo; credenciais só em header e inspeção filtrada. Respostas
usam campos permitidos, códigos de erro sanitizados e no-store. QR somente PNG
base64 estrito e com validade futura. Identificadores do vínculo precisam coincidir
com status READY antes de persistir, com chamadas HTTP anteriores ao lock local.
CSRF é obrigatório para autenticação por cookie; header presente sem token válido
não libera a ação. APIs autenticadas existentes continuam suportadas.

RED inicial de classes ausentes; GREEN 14 exemplos. Ampliação detectou consulta
DISTINCT sobre JSON do usuário (500), vínculo não READY aceito, credencial inválida
aceita e ações QR sem validação de validade/formato. O cenário de cookie primeiro
recebeu 401 porque o modo padrão Devise estava desligado; habilitado no teste,
reproduziu chamada indevida ao Broker ao acrescentar header inválido. Corrigidos.
Associação de agentes teve RED por rota ausente, sem criar transporte alternativo.

Gate final: **90 exemplos, 0 falhas**, incluindo modelos/serviços/requests novos,
InboxPolicy e Inbox existentes. **RuboCop: 16 arquivos, nenhuma infração**.
Logs `.codex/j2-*.log`. As chamadas remotas destes specs são WebMock; ainda não
constituem o contrato entre processos de J5. Não houve teste em Chatwoot remoto,
telefone real, publicação ou deploy. Overlays enterprise inspecionados: nenhuma
classe homônima substituída; políticas genéricas de inbox permanecem intactas.

## J3 — cadastro nativo e painel temporário de conexão

Card WhatsApp — JRC Broker visível somente com flag global e da conta. Factory e
wizard existentes recebem o novo canal sem alterar `Channel::Api`. Administrador
configura origem permitida e chave, seleciona conexão existente/nova e agentes;
o Broker continua sendo o único criador da inbox. Operações recentes permitem retomar
cadastro após recarga. Timeout preserva intenção/chave idempotente; rejeição HTTP
definitiva permite corrigir o formulário. UNKNOWN oferece reconciliação explícita.
O painel só abre depois da consulta que valida/persiste o vínculo no Rails.

QR/código ficam em refs, com expiração e descarte em troca de contexto, desconexão
da tela, logout, conexão estabelecida, perda de permissão ou falha de acesso. GET
não gera QR; polling visível 3s com recuo até 15s. Respostas atrasadas não atualizam
outra conta. Identidade e logout têm confirmações distintas; mudança na revisão
observada invalida a confirmação aberta. Indicadores separados para inbox, número
e transporte, sem apresentar READY como entrega comprovada. Strings novas somente
na fonte en, conforme AGENTS. Nenhuma chave é retornada ao frontend depois de salva.

RED inicial por módulos ausentes; primeiro GREEN 6 testes. Expansão detectou abertura
prematura de vínculo, formulário preso após 400 e aprovação com identidade mudada.
Teste de logout passou a usar Vuex instalado, corrigindo fixture que não injetava
o store durante setup. Gate Vitest: **13 testes / 5 arquivos, todos PASS**.
ESLint inclui explicitamente `.js,.vue`: sem erros; avisos de chaves i18n dinâmicas
e um aviso de quebra de linha. Teste Rails adicional RED mostrou que `controlKey`
camelCase escapava do filtro; filtro ampliado e GREEN **1 exemplo, 0 falhas**.
Logs `.codex/j3-*.log`. Build Vite produção completo **PASS**, 5090 módulos,
3m38s. Avisos: Browserslist desatualizado, asset de marca resolvido no runtime e
chunks grandes preexistentes. Build Rails/CI completo e inspeção de navegador
pertencem ao gate J5, ainda pendente. Integração em Settings acompanha os metadados
de vínculo e permissões de J4, para não inferir controle pelo nome do canal.
