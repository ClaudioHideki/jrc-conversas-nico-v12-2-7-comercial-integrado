# Quick NICO e Full Copilot — primeiro lote de UX

10/09/2026. Alterações isoladas na branch `codex/nico-jarvis-ux-v1`, sem push e sem commit final. Raiz do worktree: `C:/Users/DEV03/Documents/Jrc/nico-quick-ux/JRC-Conversas`.

## Diagnóstico inicial e arquitetura encontrada

O mascote abria diretamente um painel extenso. O contêiner principal usava `flex-col min-[1920px]:flex-row`: abaixo de 1920 pixels, o painel podia ocupar uma região inferior em vez de acompanhar o módulo à direita. A transcrição preenchia o campo, sem revisão temporizada nem uma apresentação consistente das fases de voz.

A implementação já tinha um controlador de sessão em `JrcCopilotPanel.vue`, estado global em `useJrcCopilot.js`, captura em `useNicoVoice.js`, API de operações e executores de ações no navegador. O servidor mantém catálogo, permissões, planejamento, idempotência, confirmações, avisos e delegações. Não foi criado outro assistente ou outra sessão.

Os seis documentos solicitados e o `AGENTS.md` foram lidos antes das alterações. A busca em `app/` e `enterprise/` não encontrou overrides dos componentes/composables de NICO alterados.

O ZIP de origem foi extraído em um repositório de baseline separado. Commit inicial do snapshot: `40bb4f46172b39fb852d8f6af1215fbb91ac83ac`. A instalação original em `lab-gopure-nico-20260908/JRC-Conversas` e sua porta 3107 não receberam este lote.

## Comportamento anterior e novo

| Antes | Agora |
| --- | --- |
| Mascote abre diretamente o painel completo | Mascote abre Quick NICO; expandir abre Full Copilot |
| Só aberto/fechado | Uma fonte de verdade: `closed`, `quick`, `full` |
| Interação curta exige painel extenso | Quick reúne contexto, resposta curta, estado, texto, voz e expansão |
| Desktop abaixo de 1920 pode empilhar painel abaixo do módulo | Drawer à direita até 1535; dock a partir de 1536 |
| Transcrição apenas preenche texto | Revisão de 1,5 segundo, edição/cancelamento e envio único ao mesmo `ask` |
| Informações secundárias precedem a conversa | Conversa, status e revisão primeiro; comprovantes e contexto acessíveis em seções expansíveis |
| `succeeded` poderia parecer execução concluída mesmo em uma resposta sem ferramenta | Resposta sem ferramenta mostra “Resposta pronta para você”; execução concluída depende do resultado real |

Quick e Full compartilham rascunho, voz, contexto e controlador. Trocar de visualização durante a revisão não reinicia o temporizador. Chamadores existentes de `open()`, `openWithPrompt()` e `openNotice()` continuam abrindo Full diretamente.

Os cards mantêm todos os argumentos, confirmação/cancelamento e execução na aba quando aplicável. O popover encaminha a revisão para Full; não oferece autorização implícita.

## Decisões de UX e breakpoints

| Largura | Full Copilot |
| --- | --- |
| Menor que 640 px | Ocupa a área inteira; módulo atrás oculto; foco circula dentro do painel |
| 640–1535 px | Drawer de 400 px à direita, sem deslocar o conteúdo para baixo |
| 1536–1919 px | Dock de 400 px; módulo continua à esquerda |
| 1920 px ou mais | Dock de 420 px |

1536 px aproveita o breakpoint `2xl` existente e preserva mais espaço para as colunas de conversas nos desktops de 1366/1440. Em 1680, o dock deixa o histórico e o envio da conversa utilizáveis.

Quick tem largura máxima de 380 px, limitada à área disponível, corpo rolável e compositor fixo. No celular há distância adicional para o mascote, que já ficava acima do envio da conversa. A faixa lateral reservada ao mascote permanece.

A ficha de contato existente usa camada visual 40 e podia cobrir o assistente. Os painéis e o launcher agora usam essa mesma camada, depois do módulo na ordem da página; os widgets de chamada permanecem acima, na camada 50. A validação final inclui a ficha aberta e verifica qual elemento realmente recebe o clique no cabeçalho e no compositor.

Foco: abrir Quick leva ao texto; expandir leva ao Full; Escape fecha; recolher devolve foco ao mascote. Full mobile tem `role=dialog`, `aria-modal` e ciclo de Tab/Shift+Tab. Estados usam região ARIA de status. As microanimações são condicionadas a `motion-safe`. Não foi adicionado CSS customizado ou estilo inline.

Atalhos existentes foram pesquisados. `Alt+N` já participa da navegação de abas; este lote mantém Escape e navegação por teclado, sem novo atalho global. Recomenda-se escolher um atalho configurável em lote próprio.

## Voz e estados

Fluxo: solicitar microfone → ouvir → transcrever → revisar → enviar ao planejador → revisar ação, executar ou receber resposta. O estado de execução vem de `busy` e dos snapshots existentes; não há progresso inventado por temporizadores.

- Push-to-talk por clique, limite de 60 segundos e 4 MiB; sem hotword, escuta permanente, realtime ou novo provedor.
- O texto aparece antes do envio. Após 1,5 segundo sem edição/cancelamento, segue como pedido ao mesmo planejador.
- Digitar ou escolher “Editar frase” cancela o autoenvio; cancelar mantém o rascunho. Digitar durante captura/transcrição invalida o áudio antigo.
- Envio manual consome a revisão. Há proteção contra callbacks duplicados e contra uma segunda captura enquanto a permissão está pendente.
- Fechar, trocar conta/conversa, iniciar chamada ou desmontar o componente cancela captura/revisão; o upload usa AbortController e tracks são encerradas.
- Uma transcrição vazia, excessiva, cancelada ou atrasada não gera pedido. O operador pode continuar por texto após negar o microfone.
- `speechSynthesis` permanece opcional. Estado “falando”, interrupção explícita e cancelamento ao iniciar gravação/chamada foram adicionados.
- Respostas antigas de leitura não podem sobrescrever a confirmação/resultado de uma operação mais recente da interface.

Enviar áudio ou dizer “sim” não confirma uma mutação. O botão de confirmação e os fluxos de autorização existentes continuam sendo o caminho de execução neste lote.

## Proteções e capacidades preservadas

O catálogo continua contendo **54 definições**. Foram comparados por SHA-256 com o baseline e permanecem idênticos: catálogo, ModuleActions, OperatorSession, ToolExecutor, OperationsController, cliente HTTP de operações, nicoModuleActions, nicoBrowserActions e nicoRunSession.

O diff não contém mudanças em controllers, services, models, policies, migrations, rotas, runtime ou API JavaScript. Pundit, escopo de conta, permissões atuais, contratos HTTP, request_id, claim/receipt e confirmação permanecem no código original.

Avisos mantêm contador, balão temporário, pausa por hover/foco, leitura explícita e acesso por “Ver aviso”. Com Quick aberto o balão fica recolhido e os avisos têm link no popover; Full mantém revisão e seções existentes. Não há dois popovers ativos.

Os widgets de SIP e WhatsApp Calling mudam apenas de posição em relação ao Full. A voz do NICO é bloqueada/interrompida pelo estado de chamada existente. Nenhum fluxo de chamada ou envio externo foi executado nesta revisão de UX.

## Arquivos alterados

Todos os caminhos abaixo são relativos à raiz do worktree.

| Arquivo | Alteração |
| --- | --- |
| `app/javascript/dashboard/components-next/jrcCopilot/useJrcCopilot.js` | Modo único e compatibilidade dos chamadores |
| `app/javascript/dashboard/components-next/jrcCopilot/JrcCopilotLauncher.vue` | Entrada Quick e preservação dos avisos |
| `app/javascript/dashboard/components-next/jrcCopilot/JrcCopilotPanel.vue` | Controlador compartilhado, estados, Full reorganizado, foco e proteção contra leituras atrasadas |
| `app/javascript/dashboard/components-next/jrcCopilot/useNicoVoice.js` | Revisão, envio único, ciclo do microfone e leitura |
| `app/javascript/dashboard/routes/dashboard/Dashboard.vue` | Drawer/dock e área mobile |
| `app/javascript/dashboard/routes/dashboard/webphone/SipCallWidget.vue` | Posição visual ao abrir Full |
| `app/javascript/dashboard/components-next/call/FloatingCallWidget.vue` | Posição visual ao abrir Full |
| `app/javascript/dashboard/i18n/locale/en/jrcNico.json` | Strings de UX na fonte i18n existente |
| `vitest.nico.config.ts` | Plugin Vue/aliases para regressões dos componentes reais |

## Arquivos novos

- `app/javascript/dashboard/components-next/jrcCopilot/JrcCopilotQuickPanel.vue`
- `app/javascript/dashboard/components-next/jrcCopilot/NicoComposer.vue`
- `app/javascript/dashboard/components-next/jrcCopilot/NicoInteractionStatus.vue`
- `app/javascript/dashboard/components-next/jrcCopilot/nicoInteractionState.js`
- `app/javascript/dashboard/components-next/jrcCopilot/specs/nicoQuickUI.spec.js`
- `app/javascript/dashboard/components-next/jrcCopilot/specs/nicoVoiceInteraction.spec.js`
- Este relatório.

## Testes e comandos

Baseline antes das mudanças: **20/20 testes, 5 arquivos**, 4,66 s, início 19:09:08 UTC.

Resultado final da suíte: **56/56 testes, 7 arquivos**, 15,01 s, início 20:03:11 UTC de 10/09/2026:

| Arquivo | Testes aprovados |
| --- | ---: |
| nicoApiAuthentication.spec.js | 3 |
| nicoBrowserActions.spec.js | 4 |
| nicoModuleActions.spec.js | 6 |
| nicoRunSession.spec.js | 4 |
| nicoVoice.spec.js | 3 |
| nicoQuickUI.spec.js — novo | 21 |
| nicoVoiceInteraction.spec.js — novo | 15 |

Os **36 testes novos** cobrem os componentes reais Quick/Full/Launcher/Composer com API e microfone simulados; modo único, foco, avisos, confirmação explícita, edição/cancelamento, trocas de contexto, gravação limitada, transcrição tardia, envio único, falhas e leitura opcional. Usam fake timers, sem sleeps reais.

Comandos centrais executados a partir da raiz (pnpm dentro de container local com dependências existentes):

```text
pnpm exec vitest run --config vitest.nico.config.ts
pnpm exec eslint <arquivos JS/Vue alterados e novos>
pnpm exec prettier --write <arquivos do lote>
git diff --check
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/nico-local-frontend.ps1
```

O helper local `.codex/check-ux.ps1` executa formatação restrita, ESLint, Vitest e diff check via `docker run --rm --network none`, imagem `jrc-nico-test:local` e volume `jrc-gopure_node_modules`. Não foram instaladas novas dependências.

ESLint: **0 erros e 20 avisos** (chaves i18n dinâmicas, textos/separadores e estilo de template; também aviso de root v-if no widget existente). Não houve correção indiscriminada fora do escopo.

`git diff --check`: aprovado. Rails não foi executado neste lote: nenhum arquivo Ruby foi alterado. Os resultados históricos Rails dos documentos anteriores não são apresentados como uma nova execução.

Build final aprovado: **5081 módulos**, concluído em **2 min 13 s**, log local `local/frontend-f156ddf6b69f4e6ca8a641ab7c90a12a.log`. O container da prévia foi reiniciado para carregar o manifesto final. Permanecem avisos de tamanho de chunks da aplicação e assets de marca resolvidos em runtime.

## Validação visual e prévia

Prévia isolada: **http://localhost:3117/app/accounts/1/conversations/14**. Container `jrc-nico-ux-web`, assets estáticos do worktree, mesma base local de homologação. Não há worker novo, migrations ou seed. O serviço original 3107 permanece separado.

Foram exercitados mascote → Quick → Full → Escape em 390×844, 1366×768, 1440×900, 1680×950 e 1920×950. Medidas DOM confirmaram ausência de overflow horizontal, um painel por vez, footer dentro da viewport e mascote sem sobrepor o envio da conversa. No mobile foram exercitados Tab e Shift+Tab; o Full ocupa 390×844. Em 1366/1440 o painel usa posição absoluta; em 1680/1920 é dockado, com larguras de 400/420 px.

Evidências locais: `C:/Users/DEV03/Documents/Jrc/output/nico-quick-ux-validation/`. `layout-final.json` contém **15 medições finais (três modos × cinco resoluções), sem falhas**. Os cliques foram conferidos após o recolhimento do balão. Foram guardadas capturas representativas de desktop e mobile; a ficha de contato foi exercitada aberta na revisão de camadas e recolhida na captura mobile.

| Resolução | Quick NICO | Full Copilot |
| --- | --- | --- |
| 390×844 | [Captura](C:/Users/DEV03/Documents/Jrc/output/nico-quick-ux-validation/quick-390x844.jpg) | [Captura](C:/Users/DEV03/Documents/Jrc/output/nico-quick-ux-validation/full-390x844.jpg) |
| 1366×768 | [Captura](C:/Users/DEV03/Documents/Jrc/output/nico-quick-ux-validation/quick-1366x768.jpg) | [Medições e cliques](C:/Users/DEV03/Documents/Jrc/output/nico-quick-ux-validation/layout-final.json) |

## Limitações

- Microfone físico, qualidade de reconhecimento do provedor e leitura audível no equipamento ainda precisam de teste humano. Os ciclos de voz foram verificados com MediaRecorder/speechSynthesis simulados.
- Não foram realizadas chamadas, mensagens externas, disparos de campanhas ou entrada em sala de vídeo. A compatibilidade foi verificada por testes existentes, estados simulados e ausência de alterações nos executores.
- A captura do navegador apresentou redução de nitidez e, em resoluções largas, corte/atraso de quadros. As capturas representativas foram inspecionadas; a validação das cinco resoluções também usa medidas DOM e verificação do alvo real de clique, registradas em `layout-final.json`.
- O ambiente de desenvolvimento mostrou aviso preexistente do mini-profiler (`Rack::File`) e aviso de Browserslist desatualizado. Não são erros do build de NICO.
- A prévia compartilha os dados locais de homologação: ações confirmadas nela modificam esses dados. A revisão visual deste lote não criou contatos, leads nem enviou mensagens a clientes.

## Pendências funcionais encontradas

Os pontos abaixo pertencem a outro lote; não foram corrigidos silenciosamente:

1. **Objetivos do operador com várias etapas e memória estruturada.** O fluxo geral ainda depende de uma ferramenta por planejamento/escrita. O ZIP já contém continuidade específica para pedidos de clientes vinculados a avisos; isso não equivale a um planejador geral de tarefas.
2. **Contato/conversa conflitantes no pedido geral.** `create_lead` ainda prioriza a conversa quando ambos os identificadores são informados. Existe validação de escopo para pedidos de cliente, mas a ambiguidade do pedido geral deve ser tratada de ponta a ponta.
3. **Cadastro de produto e diagnóstico de capacidade.** `create_product` não existe no catálogo. Ferramenta inexistente ainda pode resultar na mensagem genérica de permissão negada.
4. **Agenda e fuso.** O ZIP já contém `parse_time` com fuso da conta, configuração administrativa e validação de vínculo da atividade. A homologação anterior configurou America/Sao_Paulo. Falta evoluir a prévia amigável com data/fuso inequívocos e reavaliar os registros antigos citados na auditoria; nenhum registro foi alterado aqui.
5. **Preço/custo em reais.** A distinção entre custo e preço e a revisão legível de valores em centavos precisam de tratamento operacional próprio.
6. **Continuidade por entidades e nomes.** Quick mostra o nome disponível sem nova consulta, mas resolver referências ambíguas e evitar perguntas repetidas sobre IDs é trabalho do planejador.
7. **Confirmação por texto/voz.** Continua sendo um novo pedido, sem confirmar automaticamente a revisão. Unificar esse fluxo exige vínculo inequívoco à versão aprovada e outra homologação.
8. **Estado do atendimento.** Distinguir cliente aguardando, conversa aberta, NICO pausado, delegação expirada e humano responsável ainda demanda evolução das respostas/contexto. Os novos estados visuais descrevem a interação do operador, não o atendimento do cliente.
9. **Erros de ferramenta.** Separar falta de função, permissão, canal, dado ausente e falha do provedor; conservar detalhes seguros para diagnóstico.

Campos opcionais nulos e exigência de lead/negócio em atividades já têm correções no ZIP de origem. Não são correções deste lote.

## Estado para revisão

Branch: `codex/nico-jarvis-ux-v1`. Nove arquivos existentes alterados e sete novos, incluindo este relatório. Alterações continuam sem commit final e sem push; nenhum arquivo de credenciais ou build integra o diff. Configuração local está em caminhos ignorados.

O resumo final de `git status --short`, `git diff --stat` e o patch completo ficam junto das evidências locais. O diff concentra modo Quick/Full, compositor, apresentação de estados, ciclo de voz, posicionamento e regressões. Catálogo, APIs e lógica operacional permanecem no baseline.
