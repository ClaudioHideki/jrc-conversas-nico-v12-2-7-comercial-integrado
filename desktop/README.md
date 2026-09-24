# JRC Softphone Desktop — rodada de correção

Cliente Electron do softphone existente. Reutiliza o frontend do JRC, a API de credenciais e o SIP.js 0.21.2; não cria outro backend, registro de histórico ou protocolo de telefonia. A interface é carregada do servidor configurado. O instalador sozinho não disponibiliza as alterações Web desta worktree no servidor.

## Limite desta entrega

Na preparação local de 24/09/2026, as dependências Desktop foram instaladas com pnpm **10.2.0**, versão fixada também pelo projeto JRC. O lockfile `desktop/pnpm-lock.yaml` foi criado e preservado. Electron **44.4.5** foi confirmado no pacote e no arquivo de versão do runtime baixado; electron-builder **26.0.12** foi confirmado no pacote e na execução do build. A série Electron está suportada conforme https://releases.electronjs.org/releases/stable e https://releases.electronjs.org/schedule. Nenhuma dependência geral do JRC foi atualizada.

Os 14 testes Desktop simulados, 67 testes Web/softphone, lint e `git diff --check` passaram. O build NSIS com `--publish never` foi tentado, mas falhou por espaço insuficiente em `C:` durante o download adicional do Electron. Não foram gerados ASAR ou instalador, nem feitos release, imagem, push ou deploy. Nenhum executável do aplicativo/instalador foi aberto. A integração nativa continua pendente de homologação.

O pnpm global 11.25.0 bloqueou a dependência Git transitiva de `@electron/rebuild`; use o pnpm 10.2.0 fixado neste pacote (`corepack pnpm` ou `npx --yes pnpm@10.2.0`). A instalação informou dependências transitivas depreciadas e ignorou o script de `electron-winstaller`, relacionado a Squirrel; o alvo utilizado aqui é NSIS.

## Configuração e autenticação

Informe a URL pelo argumento `--server-url=` ou por `JRC_SOFTPHONE_URL` (a variável tem precedência). Sem configuração anterior, o aplicativo se recusa a iniciar; não presume um servidor de produção.

O Desktop exige HTTPS. HTTP só é permitido quando não empacotado, com `--development`, para `localhost`, `127.0.0.1` ou `[::1]`. Credenciais na URL (`usuario:senha@host`) são recusadas. Caminho e query podem existir na URL inicial, mas não são persistidos.

Somente `{ "origin": "https://servidor-configurado" }` é salvo em `softphone-server.json`, dentro do `userData` do aplicativo. A inicialização Windows usa o executável instalado e essa mesma origem como argumento, sem senha, token, query ou cookie. A opção de iniciar com Windows fica desabilitada no desenvolvimento.

O Desktop faz seu próprio login no JRC, pelo fluxo existente. Usa uma **sessão Electron em memória**, sem o prefixo `persist:`. Cookies, tokens e armazenamento Web não são intencionalmente persistidos pelo Desktop. **É necessário autenticar novamente após encerrar/reiniciar o processo**, inclusive no início com Windows. Ocultar/minimizar mantém o processo e a sessão em memória. Não há cofre ou arquivo adicional de credenciais SIP; o Windows/swap e políticas locais ainda fazem parte da validação do ambiente. A autenticação global do JRC não foi modificada.

Após entrada/troca de conta, o widget redireciona uma vez para `ramal_index` usando o roteador Vue, sem recarregar o renderer. No cartão do contato, **Open in JRC Conversas** abre o registro no navegador padrão através de um IPC que recebe apenas IDs. O navegador usa sua própria sessão; nenhum token é transportado no link. A tradução nova está no catálogo `en`, seguindo as regras do repositório.

## Segurança e ciclo de vida

- Instância única adquirida antes de criar janela: a segunda execução encerra e apenas restaura/foca a primeira.
- Origem configurada validada por protocolo, host e porta; navegações/redirects inesperados e subframes são bloqueados. `blob:`, `data:`, `file:` e `javascript:` não são origens navegáveis autorizadas.
- Novas janelas são negadas. Somente links sem query/hash para `/app`, conta, Ramal ou contato na origem configurada podem abrir externamente. Outros destinos e autenticação federada que saia dessa origem permanecem bloqueados; não há allowlist implícita.
- `contextIsolation`, sandbox e `webSecurity` habilitados; Node e webviews desabilitados; DevTools desabilitado no aplicativo empacotado. Isso não é uma barreira contra alguém que já controla o computador/processo.
- Ambos os handlers de permissão permitem somente mídia de áudio da janela/frame principal autorizado. Vídeo, captura de tela e permissões genéricas são negados. Erros de permissão, microfone ausente ou indisponível são apresentados pelo softphone.
- Preload limitado a avisar/limpar chamada e abrir contato. O processo principal valida remetente, frame, origem e payload, define o título, limita tamanho e frequência e rejeita IDs repetidos.
- Fechar e minimizar escondem a mesma janela. `backgroundThrottling: false` e autoplay explícito; o renderer não é destruído. Não há promessa de operação durante suspensão do Windows.
- A bandeja também abre o **controle da chamada**: uma janela local flutuante, sem navegador JRC remoto, SIP.js, `UserAgent`, credenciais ou acesso de rede. Ela só recebe estado validado do renderer principal e envia comandos validados de volta para ele. Há portanto um processo Desktop, um renderer JRC que mantém o único registro SIP e uma segunda interface de controle.
- Chamada recebida abre/foca automaticamente o controle flutuante, com Atender e Recusar. Durante a chamada, ele mostra duração e oferece mudo, espera, DTMF, transferência e desligar; sem chamada, permite discar. Fechar esse controle somente o oculta. Ao sair pelo menu, o processo pede shutdown ao renderer principal, aguarda o unregister por até três segundos e só então encerra.
- Bandeja usa `assets/tray.png`, cópia de `public/favicon-96x96.png`, com verificação `isEmpty()`.
- Falha inicial/crash: até cinco novas tentativas em 1, 5, 15, 30 e 60 segundos. Sessenta segundos de carregamento estável restauram o orçamento. Falhas repetidas não causam reload ilimitado; o menu permite tentar novamente. Sair cancela os timers. Destruição efetiva e inesperada da janela encerra o processo, evitando processo órfão sem SIP.
- AppUserModelId coincide com o instalador. A notificação nativa abre/foca o controle flutuante; falha de notificação também o abre. Atender/terminar/recusar, logout, navegação completa e crash limpam o aviso da chamada correspondente.
- Logs não recebem exceções, cabeçalhos SIP ou objetos brutos. Mensagens são sanitizadas. Logs internos de configuração do SIP.js continuam desligados.

## Registro, controles e Web

`connect()` aguarda resposta final ao REGISTER. O observador acompanha também renovações automáticas do SIP.js. Perda involuntária `Registered → Unregistered` agenda reconexão; desligamento/logout bloqueiam tentativas. Rejeições 4xx finais, exceto 408/423/480, bloqueiam retry automático até ação explícita; demais falhas usam backoff de 1/2/5/10/30 segundos. `Retry-After` estabelece um prazo mínimo, inclusive após evento `online`. O watchdog cancela o transporte/REGISTER pendente antes de permitir uma nova tentativa. Respostas de agente antigo são ignoradas.

Hold/resume só altera estado/tracks após aceitação final do re-INVITE; rejeição mantém o estado confirmado. Re-INVITEs e transferências concorrentes são bloqueados. Encerrar cancela a espera da operação.

Associação preservada do código anterior:

- `immediate`: `*3` + destino + `#`;
- `supervised`: `*4` + destino + `#`.

Falha mantém o formulário; sucesso de **envio da sequência** limpa o formulário. Isso não significa confirmação de transferência no PABX. Uma sequência antiga não continua em outra chamada. Nenhum fluxo de concluir/cancelar transferência supervisionada foi inventado: é pendência de protocolo/homologação.

O Web só notifica chamadas novas quando já tem permissão e está em segundo plano. O botão **Enable call notifications** obtém permissão por gesto antecipado do usuário. Receber ligação não pede permissão; resolução tardia de permissão não exibe chamada encerrada. Exceções/rejeições da Notification API ou bridge não interrompem o SIP. O mesmo renderer escolhe um canal de aviso: Web ou Electron.

## Mesmo ramal no Web e no Desktop — bloqueio de homologação

Não foi implementada arbitragem entre clientes. Web Locks não coordenam navegadores com Electron e não protegem o REGISTER. Ambos continuam capazes de registrar o mesmo ramal; a trava Desktop impede somente outra instância do mesmo aplicativo/perfil do Windows.

Até homologar o PABX, utilizar **um cliente SIP ativo por ramal**. Para operar o Desktop, desligar o ramal em todas as abas/perfis Web, mantendo o JRC Web disponível para CRM. Atenção: abrir um contato no navegador também pode inicializar o SIP Web se o ramal não estiver previamente desligado.

O PABX pode manter vários Contacts e tocar em ambos, substituir o registro anterior ou rejeitar o novo. A integração Hodu/CDR no repositório não prova qual política está instalada. Confirmar versão/configuração e observar REGISTER/respostas/Contacts, sem registrar Authorization/cookies/tokens, antes de definir política definitiva.

Homologar em ramal de teste: abrir clientes nas duas ordens, aguardar renovação, receber/atender/recusar, originar chamadas, perder/recuperar rede e verificar CANCEL das demais pernas, estado da UI e CDR. Não alterar produção para executar esses cenários.

## Testes disponíveis agora

Na raiz da worktree, com as dependências Web já existentes:

```powershell
node desktop/test/desktop.test.cjs
$env:TZ='UTC'
node node_modules/vitest/vitest.mjs run --config desktop/test/webphone.vitest.config.mjs --no-cache --no-coverage app/javascript/dashboard/routes/dashboard/webphone/
```

O primeiro comando executa testes Node com Electron simulado, sem instalar/iniciar Electron e sem escrever no userData. O segundo mantém os plugins/configuração do Vitest existente, restringe o diretório do softphone e usa PostCSS vazio apenas para testes funcionais. Isso contorna a ausência local de `postcss-import`; **não testa CSS/aparência** e não modifica a configuração de produção. `CallHistoryPanel` também permanece coberto por seus testes existentes.

Mocks validam contratos/estados, não áudio, entrega de DTMF/RTP, permissões do Windows, tray, toast ou comportamento do PABX.

## Reproduzir a preparação e retomar o build

Dentro de `desktop`, usar pnpm 10.2.0 e executar `pnpm install --frozen-lockfile` nas instalações seguintes. O Electron 44 baixa o runtime sob demanda; `node node_modules/electron/install.js` concluiu esse download nesta preparação sem abrir o aplicativo. Liberar espaço suficiente no disco antes de retomar o build. A limpeza de arquivos fora do Desktop não foi realizada.

`pnpm dist:win` usa NSIS com `--publish never`. Artefato esperado, ainda não gerado: `desktop/dist/JRC-Softphone-Setup.exe`. A configuração inclui `src/**/*.cjs`, `assets/tray.png` e metadados do pacote; testes e configuração do servidor do usuário ficam fora. Após build bem-sucedido, inspecionar o ASAR e calcular tamanho/SHA-256 do instalador. Instalar ou executar o aplicativo continua sendo uma etapa separada, que exige autorização. Não há auto-update, provedor de publicação ou alteração de pipeline nesta entrega. Atualizações manuais devem manter o mesmo appId; a compatibilidade com o frontend servido deve ser validada.

Windows real: instalação, primeiro login, microfone permitido/negado/ausente/ocupado, áudio bidirecional, ringtone, fechar/minimizar/bandeja, chamada oculta, clique no toast, Focus Assist, logon automático, segunda execução, rede, suspensão/retorno, encerramento e limpeza da sessão.

PABX real: registro inicial/renovação/expiração, 401/403/503/Retry-After, queda de WSS, chamadas de entrada/saída, todos os tons DTMF, `*3`/`*4`, protocolo supervisionado, hold/resume aceito/rejeitado, fim de chamada durante operação, coexistência e CDR.
