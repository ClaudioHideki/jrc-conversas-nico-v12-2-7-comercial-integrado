# Cliente simulado para validar atendimento do NICO

Ambiente: GoPure Homologação local. Contato **Marina — Cliente Simulado NICO** (53), caixa **NICO — Simulador de cliente** (66), conversa **#14**.

- Cliente: http://localhost:3107/nico-cliente-teste/
- Operador: http://localhost:3107/app/accounts/1/conversations/14

## Como testar

1. Abra os dois links em abas separadas.
2. No operador, peça ao NICO: “Assuma a conversa 14 da Marina, cliente fictícia, por 2 horas para qualificar a necessidade comercial, sem criar registros no CRM”. Revise a ação e confirme. Se já estiver ativa, continue o teste.
3. Na tela do cliente, escreva qualquer resposta como comprador ou clique em **Simular interesse de compra**.
4. A simulação envia três mensagens fixas. Cada próxima mensagem aguarda uma resposta nova do NICO, com limite de dois minutos por resposta.
5. **Pedir humano** preenche o campo; clique em **Enviar** para testar o encaminhamento.
6. **Assumir atendimento**, no painel do NICO do operador, interrompe a delegação. **Parar cliente automático**, no simulador, interrompe apenas os próximos envios do cliente.

Você pode digitar livremente como cliente; o roteiro automático é opcional e não usa outro modelo de IA. As respostas do NICO passam pelo worker e pelo provedor real configurado. Não há entrega por WhatsApp, telefone, e-mail ou webhook externo. A página usa somente a API pública do próprio contato fictício, sem chave administrativa ou de IA.

Na primeira rodada, a criação de lead estava desabilitada. Em seguida, a pedido do usuário, a conversa foi reativada com `allow_crm=true` para testar ações reais de CRM durante o diálogo livre. O comando 39 confirmou essa configuração. A autorização atual permite criar o lead da própria conversa quando houver interesse comercial; isso não concede ao cliente acesso às ferramentas administrativas do operador.

O atendimento agora transforma pedidos práticos do cliente em avisos persistentes para o operador. O NICO prepara as etapas usando o catálogo operacional e os registros vinculados ao cliente; o operador revisa e confirma cada escrita. A atualização de contato e o agendamento no CRM foram executados na conversa #14. Veja [ações e avisos](NICO-ACOES-AVISOS-20260910.md) para cobertura, validações e limites.

## Validação e correção

Na primeira execução, o NICO respondeu às três mensagens, mas repetiu a qualificação e ignorou um pedido explícito de humano. Evidência anterior à correção: `validation/nico-customer-simulator-before.json`.

A mensagem atual do cliente agora é enviada ao modelo depois do contexto histórico. As instruções de atendimento também explicitam o aproveitamento dos dados já informados, a apresentação apenas no início e a prioridade do pedido de humano. Mudanças em `services/nico-runtime/src/engine.ts` e `operations.ts`; o runtime foi compilado e reiniciado.

Verificações:

- 16 testes do runtime passaram, incluindo a preservação do pedido atual de humano após o histórico comercial.
- O pedido de humano gerou uma resposta pública de encaminhamento e estado `needs_human`: `validation/nico-customer-simulator-handoff.json`.
- A retomada explícita pelo operador gerou estado `paused`; uma nova mensagem não recebeu resposta automática na janela observada de 10 segundos: `validation/nico-customer-simulator-human.json`.
- Sem reenviar os dados, foi perguntado o que o NICO lembrava. Ele recuperou **10 operadores, WhatsApp e telefone, até 30 dias**.
- O histórico final e o estado observado estão em `validation/nico-customer-simulator.json`.
- Após a correção, uma nova rodada completou três mensagens e três respostas correlacionadas pelos IDs. As verificações estão em `validation/nico-customer-simulator-checks.json`.

Na rodada anterior, o NICO ainda repetia a saudação. A atualização de ações e avisos acrescenta uma regra de continuidade no contexto e remove saudações iniciais repetidas no servidor, preservando o nome e o conteúdo. A resposta nova à mensagem #70 começa com “Marina, vou solicitar ao responsável...”, sem repetir “Olá”. O histórico anterior foi preservado.

Esses testes cobrem esta conversa e esses cenários locais. Não são validação de entrega em canais externos nem garantia de qualidade para toda formulação de mensagem.

## Recriar a tela no ambiente local

Os comandos abaixo rodam no diretório do projeto. O script reutiliza o contato e a conversa existentes, preservando mensagens. Ele exige o ambiente local de desenvolvimento.

```powershell
docker compose -p jrc-gopure -f docker-compose.nico-local.yml -f docker-compose.nico-package.yml -f docker-compose.nico-provider.yml exec -T web node node_modules/tailwindcss/lib/cli.js -c scripts/nico-customer-simulator/tailwind.config.cjs -i scripts/nico-customer-simulator/input.css -o scripts/nico-customer-simulator/styles.css --minify
docker compose -p jrc-gopure -f docker-compose.nico-local.yml -f docker-compose.nico-package.yml -f docker-compose.nico-provider.yml exec -T web bundle exec rails runner scripts/nico-customer-simulator.rb
```

A pasta pública é gerada e ignorada pelo Git. O script de verificação `scripts/nico-customer-simulator-check.mjs` aceita `inspect`, `delegate`, `delegate-crm`, `verify-human` e `verify-handoff`; todos, exceto `inspect`, executam ações somente na conversa do simulador. `delegate-crm` habilita a criação de lead; `delegate` mantém essa permissão desabilitada. A delegação de teste expira em duas horas.
