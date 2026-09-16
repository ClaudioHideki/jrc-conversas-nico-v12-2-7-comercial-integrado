# Execução local — integração nativa JRC Broker

Branch `codex/jrc-broker-native`, worktree isolado `jrc-broker-native-20260916`.
HEAD de partida `f38fe020057277cf5d2733460915e67451898165`; baseline do pacote
`62c14af884c7f45fa640345556f2ffecc22113d8`. Os cinco commits posteriores e o outro
checkout com `db/schema.rb` modificado foram preservados. Broker plano 01 concluído
localmente até `eeb3b38`, incluindo OpenAPI regenerado depois do commit sem diff.

Sem push, merge, publicação, deploy, credenciais remotas ou números reais.
Plano 02 implementado; build Docker de CI permanece bloqueado pelo ambiente local.
Plano 03 segue no Broker. Piloto remoto depende de autorização separada.

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

## J4 — acesso pelo atendimento e concessões

ConversationHeader usa o vínculo confirmado retornado pelo servidor e um botão que
confere autorização antes de abrir o Dialog já existente. Troca de conversa/conta/
inbox fecha o modal; logout limpa estado. O painel reutilizado não contém formulário
de configuração nem edição de concessões. A aba JRC nas configurações da inbox contém
o painel administrativo de grants, limitado aos membros atuais da própria inbox.

Metadado `jrc_broker_bound` depende da flag global, da conta e de registro persistido;
additional_attributes e nome não têm autoridade. Preload evita consulta adicional por
inbox na listagem habilitada. Vínculo toca a inbox para atualizar cache. Webhook URL
de Channel::Api passa a ser mostrado somente ao admin, assim como secret/hmac_token;
a URL pode carregar segredo de callback e não é necessária ao agente. Consumo no
frontend existente conferido: configurações administrativas; transporte preservado.

RED Vue por componentes ausentes; GREEN **15 testes / 7 arquivos**. ESLint: zero
erros, avisos de i18n dinâmico e formatação/preexistentes documentados nos logs.
Primeiro RED Rails foi bloqueado por perda temporária do daemon Docker; isso não
foi contado como falha funcional. Docker retornou, somente os três containers desta
tarefa foram iniciados e RED real confirmou campo ausente. GREEN/regressão de APIs
de inbox, Dashboard Apps e InboxPolicy: **132 exemplos, 0 falhas**. Após extrair a
extensão para concern e normalizar quebras de linha dos arquivos tocados, RuboCop:
**7 arquivos, aprovado**; regressão posterior com Inbox: **73 exemplos, 0 falhas**.
Inclui agente associado a duas inboxes com concessão em somente uma. Logs `.codex/j4-*`.
Não houve acesso a Chatwoot remoto ou telefone. Build integrado final segue em J5.

## J5 — contrato real entre processos e recuperação antes do ACK

Laboratório descartável executa Rails, Broker, PostgreSQL/RLS e TLS de verdade.
Provedor de telefone é sintético. Gateway aceita somente dois serviços locais fixos;
certificado próprio confiado nos backends, sem desativar verificação TLS/SSRF.
Banco Broker `jrc_contract_20260916`; conta Rails sintética distinta de produção.
Fixtures reproduzíveis em `tests/playwright/fixtures/jrc-broker/`, excluídas da imagem
por `.dockerignore`, assim como `.codex` com evidências e credenciais temporárias.

Falhas anteriores de quota da fixture (limite inicial de duas instâncias) e email
duplicado da factory foram corrigidas no teste. Não eram falhas do produto.
Contrato final `.codex/j5-contract-security-fixed.log`: **3 exemplos, 0 falhas**.
Autenticação BFF e chave limitada reais; onboarding repetido cria uma única inbox
por intenção; pareamento passa por Rails, sem chave no browser; chave de outra
conta recusada; rollback da flag preserva webhook. Gateway mediu **zero transações
ociosas abertas** durante POST de criação da inbox em ambos os bancos.

Teste força 503 antes de encaminhar o callback ao Broker. `WebhookJob` reenvia
assinatura real, preservando corpo/ID de entrega; Broker persiste somente um
`CHATWOOT_REPLY` após replay e recusa HMAC falso. Adaptador de testes do ActiveJob
adianta o backoff: não é teste de reinício Sidekiq/Redis nem entrega em telefone.
Chatwoot externo ainda precisa comprovar sua própria recuperação no piloto.

Correção do emissor limitada a mensagens públicas de saída em inbox JRC persistida:
até oito tentativas para falhas transitórias, verificação de URL/segredo atuais,
falha final neutra e nenhuma credencial em logs. Flag da interface não interrompe
retry. RED funcional **4 falhas**, GREEN/regressão inicial **62 exemplos, 0 falhas**
(`j5-retry-red-functional.log`, `j5-retry-green.log`). O primeiro RED por DNS da
fixture foi bloqueio de ambiente, não evidência funcional.

Navegador identificou sobreposição `relative`/`fixed` na sidebar móvel herdada e
`col-span-6` fora do breakpoint desktop. Ajuste mantém sidebar sobreposta no móvel,
e conteúdo ocupa uma coluna até `lg`. Teste inicial desktop também corrigiu seletor
de combobox por nome acessível. Logs anteriores de timeout durante reload em Docker
Desktop foram diagnosticados em FileUpdateChecker; somente runtime HTTP sintético
recebe `enable_reloading=false` para servir snapshot compilado fixo.

### Gates de J5

- RSpec regressão: **211 exemplos, 0 falhas**, incluindo novos modelos/services/
  requests, inboxes, Dashboard Apps, políticas, agent bots e transporte existente.
  `.codex/j5-regression.log`.
- Vitest: **15 testes / 7 arquivos, todos PASS** (`j5-vue.log`).
- RuboCop: **20 arquivos, nenhuma infração** (`j5-rubocop-clean.log`). Normalizadas
  quebras de linha Windows na cópia Linux dos arquivos JRC para executar o lint.
- ESLint da integração e InboxChannels: **0 erros / 14 avisos** de i18n dinâmico e
  formatação (`j5-eslint-feature.log`). Sidebar herdada tem erros preexistentes;
  comparação com HEAD por ESLint mostra **nenhuma infração adicionada**
  (`j5-eslint-sidebar-baseline.log`). Não se declara lint global aprovado.
- Build Vite produção após correção responsiva: **PASS**, 5092 módulos, 5m12s;
  avisos de Browserslist/chunks/asset de marca preexistentes. `j5-vite-mobile-build.log`.
- Playwright Chrome, desktop 1440×1000 e mobile 390×844: **2 PASS**, 56,7s
  (`j5-browser-final.log`). Cadastro até pareamento, foco/Enter, armazenamento sem
  código, ausência de chave no HTML, nenhuma chamada browser→engine/Broker e troca
  de conta. Capturas sintéticas antes de gerar código em `.codex/`, não versionadas.
- Varredura: **17 arquivos alterados e 477 assets**, nenhuma das credenciais do
  laboratório presente (`j5-artifact-check.log`). Não substitui revisão geral de
  segredos; flags e credenciais não foram habilitadas em produção.
- Build real `docker/Dockerfile`: **BLOCKED**. Iniciado com snapshot isolado, sem
  env privado, interrompido ainda em `bundle install`/dependências nativas após
  pressão de memória (aproximadamente 440 MiB livres em 12 GiB). Exit -1 por
  interrupção deliberada, sem imagem final. `.codex/j5-ci-build.log`. Repetir no CI
  ou máquina com recursos livres, usando HEAD final e `.dockerignore` atualizado.

Inspeção enterprise: sem overrides homônimos de WebhookJob/Trigger, Sidebar ou
InboxChannels. Regras de tradução mantidas: strings fonte en; homologação pt-BR
depende do pipeline de tradução do projeto. NICO/Comercial não foram reimplementados;
regressão funcional integral dessas áreas não foi executada. Não há evidência de
telefone, ambiente remoto, reinício de fila ou implantação.

Revisão final: o primeiro probe instantâneo contou uma transação breve concorrente
do worker, causando falso positivo de A26 (`j5-contract-final.log`). A fixture passou
a comparar duas observações, retendo o HTTP por 150 ms em cada banco; nenhuma
transação retida foi observada. Contrato repetido após refatoração:
**3 exemplos, 0 falhas** (`j5-contract-probe.log`). Playwright repetido com capturas
do formulário preenchido e revisão visual: **2 PASS, 55,2s**
(`j5-browser-reviewed.log`). Sem alteração de produção entre esses gates.
