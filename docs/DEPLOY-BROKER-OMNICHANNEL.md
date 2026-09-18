# JRC Conversas e Flows administrados pelo Broker — 18/09/2026

Branch isolada: `codex/jrc-omnichannel-20260918`, base `3d0c981` do candidato
`codex/jrc-flows-broker-release-20260917`. Alterações da worktree anterior foram
preservadas. Este complemento amplia o escopo de `DEPLOY-FLOWS-BROKER.md`:
o cliente também pode administrar o chatbot no Broker, inclusive para caixas de
outras instalações Chatwoot compatíveis.

## Uso no JRC

O módulo nativo **Conectar seu WhatsApp** continua atendendo administradores e
agentes autorizados fora da conversa. A configuração de origem do Broker,
empresa, chave de controle e caixas segue o guia anterior.

Para automação, escolha um motor por caixa:

- **Flow nativo JRC:** editor, execução e credenciais no JRC, como na release de
  17/09. Preserve os requisitos de Sidekiq/sandbox e suas flags.
- **Flow no Broker:** editor no Broker → publicar → Conexões → Caixas do Chatwoot
  / JRC → ativar. O Broker associa um Agent Bot à caixa e recebe eventos
  assinados. Instagram/e-mail precisam estar configurados no JRC antes disso.

Não há sincronização automática de definições, execuções ou credenciais entre
esses motores. O motor inicial do Broker possui mensagem, entrada, condição,
variável, transferência humana e fim; não oferece toda a execução n8n/JavaScript
do módulo JRC. Não é necessário cadastrar um Dashboard App para usar o Agent Bot.

## Correção incluída

O dispatcher, os dois executores e a entrega de Flows nativos consultam a
associação **ativa de Agent Bot à caixa**, além da atribuição da conversa. Isso
evita uma segunda resposta quando o bot foi vinculado depois que a conversa já
existia ou quando uma resposta nativa estava na fila. A consulta usa o estado
atual do banco, sem depender de associação Rails previamente carregada.

O padrão da API Chatwoot permanece inalterado. Não foram encontrados overlays
Enterprise dessas classes. Esta correção não cria migração nova no JRC.

## Validação local real

- `bundle exec rspec spec/requests/api/v1/accounts/jrc_flows_spec.rb`: **9 exemplos,
  zero falhas**, em Rails de teste com PostgreSQL/Redis descartáveis. Os dois
  exemplos novos falharam antes da correção e passaram depois: conversa anterior
  à associação do bot; retomada/entrega nativa após associação do bot.
- `db:schema:load db:migrate` executado no banco descartável exclusivo.
- RuboCop nos seis arquivos: base e candidato têm **77 ocorrências**. Não é
  resultado de lint limpo. Dez diagnósticos existentes de complexidade/tamanho
  têm valores maiores após as guardas; não se fez limpeza geral desses métodos.
  Logs JSON locais: `.codex/lint-baseline.json` e `.codex/lint-current.json`.
- Logs RSpec: `.codex/ownership-red.log` e `.codex/ownership-green.log`.
- Nenhum teste desta correção enviou mensagens reais ou acessou produção.

## Atualização futura

Revise o candidato, publique a revisão somente quando autorizado e coloque a
mesma imagem em **Rails e Sidekiq**. Use o workflow da release conjunta já
documentado; esta tarefa não publicou imagens JRC/GHCR nem alterou o Dokploy.
Mantenha os módulos e o sandbox conforme `DEPLOY-FLOWS-BROKER.md`. Desative o
flow nativo da caixa antes de ativar o Agent Bot do Broker.

No Broker, use `codex/broker-omnichannel-20260918` e seu guia
`docs/operations/broker-omnichannel.md`. É necessário aplicar as migrações do
Broker e atualizar API, worker e web. Homologue a combinação das duas versões
antes de liberar os clientes. Se o cliente tem apenas Chatwoot compatível, o
Agent Bot não exige a instalação deste módulo nativo JRC.

Antes de retornar ao JRC anterior, retire os Agent Bots do Broker das caixas e
pause suas automações; não reative simultaneamente o motor nativo. A imagem de
produção informada pelo operador foi `sha-f38fe02`; sua permanência no servidor
não foi verificada nesta tarefa.
