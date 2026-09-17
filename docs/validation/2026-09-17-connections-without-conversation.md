# Conexão WhatsApp independente de conversa

## Escopo e base conferida

Solicitação de 17/09/2026: o agente precisa localizar sua caixa e reconectar o
WhatsApp antes de existir uma conversa. Dashboard App dentro do atendimento não
atende a essa entrada principal.

- Base real: `3dd2e48b96d177776256fdcd1700e29bb0c9fed1`, branch
  `codex/jrc-broker-native`, worktree limpo antes deste incremento.
- Novo worktree: `jrc-broker-connections-20260917`, branch
  `codex/jrc-broker-connections`. Mantém os commits anteriores do módulo.
- Nenhuma alteração no Broker, banco ou código dos ambientes locais 3116/3117.
  Não houve push, merge, publicação de imagem, deploy ou número real.

## Alteração

- Entrada **Conectar seu WhatsApp** na seção Atendimento, condicionada às flags
  da instalação e da conta.
- Página `/app/accounts/:accountId/whatsapp-connections`, disponível para agente
  sem liberar configurações administrativas. Funciona com zero conversas.
- Listagem pelo endpoint Rails existente de inboxes: administrador vê caixas da
  conta; agente vê caixas atribuídas. Somente `jrc_broker_bound` confirmado pelo
  servidor habilita o controle; nome e atributos arbitrários não criam vínculo.
- Reutiliza `ConnectionPanel` e o backend intermediário existente. Status não
  solicita QR automaticamente. Não há chamada browser→engine, nova chave no
  navegador ou autenticação do iframe por token administrativo.
- Troca de conta/caixa, logout, atualização ou saída da página desmontam o painel,
  descartam QR e cancelam requisições. Resposta atrasada da conta anterior é ignorada.
- Aba administrativa da inbox recebe o mesmo título. O atalho na conversa permanece
  opcional. Primeira identidade continua exigindo administrador; agente com grant
  reconecta a identidade aprovada, sem poder trocar número ou credenciais.
- Sem migração nova. A instalação inicial do módulo nativo ainda exige as tabelas
  de configuração, vínculo e delegação já implementadas na base.
- Strings-fonte em inglês e sete textos da nova página em pt-BR, limitados ao
  rótulo e à experiência em português explicitamente solicitados pelo usuário.

## Resultados desta execução

| Verificação | Resultado |
|---|---|
| RED da página | PASS: import de `ConnectionsPage.vue` inexistente antes da implementação |
| Vitest do módulo | PASS: **23 testes, 9 arquivos**, incluindo oito novos testes |
| ESLint de novos arquivos, API e registro de rotas | PASS, sem mensagens após formatação |
| Lint de Sidebar/Settings contra HEAD | PASS: zero ocorrências adicionadas; Sidebar mantém 23 preexistentes, Settings mantém zero. CRLF normalizado apenas na leitura |
| `git diff --check` | PASS |
| Build integral de frontend/imagem | NOT_RUN neste incremento |
| Navegador com Rails/Broker real para a nova página | NOT_RUN neste incremento |
| Instalação nativa no laboratório 3116/3117 | NOT_RUN; mantém a demonstração de Dashboard App existente |
| Telefone/produção/publicação | NOT_RUN, fora do escopo autorizado |

Casos novos: conexão sem conversa; filtro de vínculo persistido; mudança de caixa;
resposta atrasada de outra conta; logout; flag desligada; erro distinguido de lista
vazia com repetição explícita; nenhuma caixa disponível; agente sem permissão de
parear; chamadas à origem Rails com conta capturada. O teste de API verifica a URL
e o cancelamento, mas não substitui a autorização real no Rails. Nenhuma mudança
Ruby foi feita; resultados RSpec anteriores não são apresentados como execução nova.

Vitest usou as dependências locais existentes do worktree-base via junction.
O pnpm global 11 era incompatível com o projeto 10.x; usado diretamente o binário
Vitest 3.0.5 já instalado. Vite precisou permitir o diretório das dependências no
config de teste ignorado `.codex/vitest.connections.config.mts`. `NODE_PATH`
apontou para `node_modules/.pnpm/node_modules` para resolver o PostCSS existente.
Tentativas bloqueadas por dependência/processo não foram contabilizadas como RED.

Comando final (PowerShell, escopo do processo):

```powershell
$env:NODE_PATH = (Resolve-Path node_modules/.pnpm/node_modules).Path
node node_modules/vitest/vitest.mjs run --config .codex/vitest.connections.config.mts app/javascript/dashboard/components-next/jrc-broker/__tests__ --maxWorkers=1 --minWorkers=1
```

Logs locais ignorados: `.codex/connections-red.log`, `connections-green.log`,
`connections-eslint.log`, `connections-eslint-baseline.log`. Execução final dos
testes: 164,71 s. Durante validação, o host chegou a 598 MiB livres em 12 GiB;
não foi iniciado outro build pesado. O container de testes nativo, iniciado para
inspeção, foi devolvido ao estado parado. Nenhum certificado foi instalado.

## Antes de mostrar no laboratório ou distribuir

1. Integrar o módulo nativo na versão real do JRC Conversas de laboratório,
   preservando os incrementos Flows/NICO/CRM desse fork. A imagem atual não contém
   este código; publicar apenas o Broker não altera sua navegação.
2. Compilar e validar em navegador a rota, menu, aba, desktop/celular, agente e
   administrador contra Rails/Broker reais. Validar as traduções dos controles
   anteriores; esta entrega traduz somente os textos novos.
3. Configurar origem, chave de controle cifrada, flags e vínculos nativos de teste.
   Caixa criada antes pelo portal não vira vínculo nativo por nome ou URL: requer
   conciliação administrativa com os IDs confirmados pelo Broker.
4. Para cliente externo, homologar a versão/fork e entregar patch versionado com
   migrações, build, testes de contrato e rollback por flag. Este código não foi
   empacotado nem testado como plugin universal do Chatwoot.
5. Sem instalação de código no cliente, usar o portal JRC para conexão inicial;
   Dashboard App é atalho na conversa. URL, account ID, token e webhook não inserem
   menus, não criam login único e não estendem as configurações da inbox.

Referência oficial conferida:
[Dashboard Apps](https://www.chatwoot.com/hc/user-guide/articles/1677691702-how-to-use-dashboard-apps).
