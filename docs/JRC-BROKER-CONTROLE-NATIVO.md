# Controle nativo do JRC Broker

Incremento de 16/09/2026. Evolui o canal API existente. O Broker cria a inbox,
mantém a sessão WhatsApp e transporta mensagens. O Rails autentica o usuário,
limita sua autoridade à conta/inbox e chama o Broker no servidor.

## Ativação por conta em homologação

1. Aplicar a migração `20260916163000_create_jrc_broker_integration_tables` no
   banco de homologação, com backup e a versão correspondente do Broker.
2. Configurar `JRC_BROKER_ENABLED=true`, `JRC_BROKER_ALLOWED_ORIGINS` com as origens
   HTTPS exatas do Broker (separadas por vírgula), `FRONTEND_URL` com a origem
   HTTPS desta instalação e `JRC_BROKER_CREDENTIAL_KEY` com 32 bytes aleatórios
   codificados em Base64. A chave de cifra pertence ao cofre do servidor.
3. Habilitar a feature `jrc_broker` somente na conta piloto. No Broker, aprovar
   o destino, vincular a mesma conta Chatwoot e emitir chave com os escopos
   `chatwoot:read`, `chatwoot:pair`, `chatwoot:disconnect`, `chatwoot:manage`.
   A chave fica vinculada à organização, conta e revisão do destino.
4. Como administrador da conta, abrir **Configurações → Inboxes → Adicionar →
   WhatsApp — JRC Broker**. Informar origem, organização e chave de controle.
   A chave é cifrada no Rails e não volta nas respostas. O token administrativo
   Chatwoot usado pelo Broker é outra credencial e não deve ser entregue a agentes.
5. Escolher conexão nova/existente, nome da inbox e agentes. Aguardar o cadastro.
   Se a resposta se perder, retomar a operação recente. `UNKNOWN` exige conciliar
   os recursos; não criar outra inbox para contornar o erro.
6. Solicitar o código, conectar o número de homologação autorizado e confirmar
   sua identidade como administrador. Testar entrada e saída antes de liberar
   atendimento. Inbox configurada e número conectado são estados diferentes
   de transporte comprovado nas duas direções.

## Permissões e códigos

Na aba **Conectar seu WhatsApp** da inbox, o administrador pode conceder reconexão
a membros atuais. O agente acessa **Conectar seu WhatsApp** no menu de atendimento,
seleciona uma caixa autorizada e consulta seu estado ou solicita o QR. A página
`/app/accounts/:accountId/whatsapp-connections` funciona sem contato ou conversa.
O botão **Conexão** no atendimento permanece como atalho opcional.
O agente reconecta somente uma identidade já aprovada. Ele não configura credenciais, não cria a primeira vinculação, não
aprova outro número e não desconecta. Remover a associação à inbox remove o grant.
Revogação é verificada novamente no servidor; a interface descarta o código.

Um número pertence à caixa e à empresa; não é criado automaticamente para cada
login de agente. Vários agentes podem atender uma mesma caixa. A listagem reutiliza
a política de inboxes do Rails; o controle revalida o vínculo e a delegação em cada
chamada. A página não libera configurações administrativas para agentes.

O código é temporário, não aparece automaticamente ao consultar status e fica
somente na memória da tela. Expiração, troca de contexto, logout e perda de acesso
descartam o valor. Solicitar outro código representa uma nova intenção explícita.
Uma identidade diferente pausa o transporte até confirmação administrativa.

## Chatwoot de terceiros

- **Sem modificar o Chatwoot:** a API de inbox e o webhook transportam mensagens.
  O portal do Broker oferece conexão independente de conversa. O Dashboard App
  pode ser configurado como atalho dentro de uma conversa; não instala menu nem
  aba nas configurações da inbox. O login do Chatwoot não autentica automaticamente
  esse portal ou iframe.
- **Com acesso nativo:** instalar a integração Rails/Vue desta branch no código
  da versão homologada do cliente. Reutiliza autenticação do Chatwoot, canal API,
  API de controle do Broker e vínculo da caixa; a chave de controle fica cifrada
  no backend. A instalação inicial exige as tabelas aditivas do módulo original.
  Este incremento de navegação não acrescenta migrações.
- **Distribuição:** entregar patch versionado, requisitos, migrações, feature flag,
  testes de contrato e procedimento de rollback. Não há pacote universal testado
  em qualquer versão/fork. É necessário acesso ao código/build da instalação;
  somente token da conta não permite alterar a interface de um serviço hospedado.

Para conta já provisionada exclusivamente pelo portal, não deduzir o vínculo
nativo pelo nome, webhook ou atributos arbitrários. Conferir o mapeamento com a
API de controle e estabelecer o registro local pelo fluxo administrativo
homologado antes de habilitar agentes. As contas do laboratório de Dashboard App
não foram convertidas automaticamente por este incremento.

Referência: [Dashboard Apps do Chatwoot](https://www.chatwoot.com/hc/user-guide/articles/1677691702-how-to-use-dashboard-apps),
consultada em 17/09/2026: o ponto de extensão documentado é a janela da conversa.

## Credenciais e indisponibilidade

- **Rotação da chave de controle:** emitir uma nova chave limitada no Broker,
  substituir na configuração administrativa desta conta, validar status e então
  revogar a antiga. A tela não recupera o segredo anterior.
- **Rotação da chave de cifra Rails:** conservar a chave antiga até recifrar os
  registros em manutenção controlada ou reconfigurar cada conta. Trocar apenas a
  variável torna as credenciais armazenadas ilegíveis e bloqueia o controle.
- **Token Chatwoot revogado:** revalidar/revincular a conta no Broker. A evidência
  anterior de capacidades/transporte deixa de valer após a troca de credencial.
- **Broker indisponível:** preservar inbox e sessão. Para chamadas de controle,
  repetir apenas a mesma intenção idempotente; o cadastro incerto requer conciliação.

## Entrega antes da confirmação do Broker

`WebhookJob` continua sendo o único transporte da inbox API. Para mensagem pública
de saída `message_created` em inbox com vínculo JRC persistido, falhas transitórias
de conexão e HTTP 408/425/429/5xx são reenviadas até oito tentativas, com espera
progressiva. O corpo e o identificador da entrega são preservados; o timestamp e
a assinatura são recalculados. O Broker deduplica pelo ID da mensagem.

Antes de cada tentativa, URL e segredo precisam coincidir com a configuração atual
da inbox. Mudança de contexto ou rejeição permanente encerra as tentativas. Após
esgotamento, a mensagem recebe código neutro de falha. Confirmar o estado no Broker
antes de reenviar manualmente uma entrega cujo ACK pode ter sido perdido.

O teste local observou 503 antes do ACK, reenvio assinado, persistência única e
rejeição de assinatura falsa. A execução RSpec adianta as tentativas pelo adaptador
de testes do ActiveJob: não constitui teste de reinício do Sidekiq/Redis. Persistência,
backup da fila e recuperação após reinício precisam ser exercitados no piloto.
Chatwoot de terceiros sem este incremento tem comportamento de retry próprio;
a recuperação deve ser verificada nessa instalação antes de homologar entrega.

## Rollback operacional

Desligar `jrc_broker` na conta ou `JRC_BROKER_ENABLED` oculta o controle e bloqueia
os endpoints novos. Isso preserva o webhook, a inbox, os grants e a sessão do
número. A recuperação do transporte não depende da flag de interface.
Não executar migration down, apagar vínculos ou fazer logout como rollback da UI.
Para interromper transporte, usar o controle operacional explícito no Broker.

## Validação e limites

Incremento local de 16/09/2026: migração aditiva de configuração, vínculos e grants;
backend de controle por conta; cadastro nativo; reconexão delegada pelo atendimento;
retry assinado do webhook JRC e correção do assistente no celular. O build Vite,
contrato entre processos e testes Rails/Vue/browser passaram. O build Docker de CI
ainda requer execução em ambiente com recursos disponíveis; não há liberação de
imagem ou deploy neste incremento.

Evidências e comandos estão em `docs/validation/2026-09-16-jrc-broker.md`.
As fixtures em `tests/playwright/fixtures/jrc-broker/` são exclusivamente locais,
com banco descartável, nomes `.example.test` e provedor de telefone sintético.
Nenhum teste local autoriza publicação, deploy ou uso de números reais.
