# Flows — motor interno, importação n8n e teste local

> Registro do laboratório de 16/09. Para o candidato consolidado, habilitação por conta, imagens e Dokploy, use [DEPLOY-FLOWS-BROKER.md](DEPLOY-FLOWS-BROKER.md). Os testes repetidos nesta release constam em [VALIDACAO-FLOWS-BROKER.md](VALIDACAO-FLOWS-BROKER.md); as evidências históricas abaixo não substituem esse aceite.

## Entrega de 16/09/2026

O JRC tem um motor próprio de workflows. A execução, edição, credenciais, memória e histórico ficam no módulo Flows. Não há iframe do n8n nem chamada a webhook de uma instância n8n. O serviço interno QuickJS apenas interpreta JavaScript isolado; Rails executa as integrações autorizadas e Sidekiq processa as mensagens.

O botão **Novo flow** abre uma janela centralizada mesmo com a lista rolada. A importação reconhece conteúdo JSON, inclusive BOM UTF-8 e arquivos `.txt` contendo JSON, e identifica o formato antes de criar o rascunho. Limite: 2 MB; 150 nós para execução. Os blocos nativos novos evitam posições já ocupadas.

## Criar e testar

1. Abra `http://localhost:3116/app/accounts/1/flows` como administrador.
2. Clique em **Novo flow** e selecione **Workflow avançado · código, IA e integrações**. Os modelos anteriores continuam disponíveis para mensagens, espera, CRM, atendimento e Nico.
3. Selecione uma caixa de teste. O modelo avançado contém entrada, código e resposta, executáveis no JRC.
4. Edite os nós no painel lateral. **Ir para nó** permite navegar em grafos grandes. Condições e opções avançadas ficam nos parâmetros JSON; prompts e JavaScript têm campos próprios.
5. Salve, valide e use o Playground. O Playground executa a lógica e usa memória temporária, mas para antes de IA e HTTP: não envia mensagens, não chama APIs e não altera o CRM.
6. Para teste real, ative numa caixa de homologação sem outro bot/atendente. Uma mensagem recebida passa pelo Sidekiq; a resposta é criada na conversa e entregue pelo adaptador do canal. A resposta de um atendente pausa a execução.

## Compatibilidade implementada

| Nó importado | Execução no JRC |
|---|---|
| Webhook / Execute Workflow Trigger | Entrada interna: mensagem da caixa ou dados do subworkflow. A URL e a autenticação do webhook do n8n não são utilizadas. |
| Code | JavaScript síncrono, `$input.first/all`, `$json`, `$('Nome').first/all`, `$node`, `$items`; sem Node.js, módulos, rede, filesystem ou variáveis de ambiente. |
| IF / Switch | Regras com igualdade, diferença, verdadeiro/falso, contém, começa com, existência, vazio e comparações numéricas. |
| Redis | get/set/delete no Redis do JRC, isolado por conta e flow; TTL máximo de 7 dias. Não usa a credencial Redis do n8n. |
| AI Agent + OpenAI Chat Model | Instruções e entrada do agente, modelo e temperatura. Chave OpenAI configurada no JRC e chamada via Chat Completions. |
| Execute Workflow | Executa um flow da mesma conta, selecionado no campo **Subworkflow no JRC**; até quatro níveis. |
| HTTP Request | HTTPS público, GET/POST/PUT/PATCH/DELETE, corpo JSON, cabeçalhos e credencial HTTP do JRC. Sem redirecionamentos. |
| Set / NoOp / StickyNote | Atribuições simples, passagem e anotação. |
| Respond to Webhook | Converte a saída em resposta do chatbot no JRC. |
| continueOnFail / continueRegularOutput | Encaminha o erro real ao próximo nó para o tratamento definido no workflow. |

Isso é um conjunto de compatibilidade, não a implementação integral do n8n ou Typebot. Não inclui nós comunitários, Python, módulos npm em Code, chamadas assíncronas dentro de Code, ferramentas/memória LangChain conectadas ao agente, joins com múltiplas entradas, arquivos binários n8n, retries automáticos, saída separada de erro nem todos os modos/opções de cada nó. Tipos e estruturas não suportados são recusados quando identificados; toda importação exige revisar o caminho e suas opções antes de ativar. JSON de Typebot não é convertido nesta versão. Agente de voz continua em planejamento.

Limites adicionais: 200 passos por turno, 200 turnos por sessão, até 100 itens por saída e 2 MB no pedido ao sandbox. Código tem limite de 2 segundos/32 MB e prazo externo de 4 segundos; chamadas HTTP têm prazo de 55 segundos e resposta de até 200 KB. Não há reexecução automática de um turno cujo resultado de integração ficou incerto.

## JSON de entrada e saída

A entrada está em `$json.body` e também diretamente em `$json`, com `event_type`, `mensagem`, `message_id`, `conversation_id`, `tenant_id`, `telefone`, `origem`, `canal`, `environment` e `human_active`. Identificadores de conversa/mensagem incluem conta e execução para separar sessões. Mensagens de texto são o caminho implementado; áudio, imagens e anexos precisam de blocos/adaptadores de transcrição e processamento.

Saída simples:

```json
{"messages":["Olá! Como posso ajudar?"],"handoff":false,"close":false}
```

`handoff: true` aceita `destination: "SUPORTE" | "FINANCEIRO" | "COMERCIAL"` e `summary`. Configure a equipe padrão e os destinos em Configurações. `close: true` resolve a conversa. Até dez mensagens por turno.

O contrato Ligo do JSON Jade também é reconhecido: `mensagem`, `mensagem_2`, `acao`, `transferir_ligo`, `encerrar_ligo`, `ignorar_ligo`, `destino` e `resumo_handoff`. Transferência entre bots (`TRANSFERIR_BOT`, destino MOCCHI) ainda depende de um adaptador específico; não é convertida silenciosamente em atendimento humano.

## O chatbot Jade recebido

O arquivo de 62 nós está importado no ambiente local como rascunho. Código, prompts, conexões, configurações e referências originais foram preservados. O caminho **START** executou 21 nós no Playground e produziu a saudação original da Jade.

Para ativar a jornada completa, ainda é necessário:

- Configurar a chave OpenAI, caixa e equipes em Configurações.
- Importar `JRC | CORE | BTV | CLIENTE E FINANCEIRO | v3.6 HML FAIL CLOSED`, referência original `QhTkMxRZYo3I0RYF`.
- Importar `JRC | CORE | KSYS | SUPORTE HELPDESK | v3.10 HML FAIL CLOSED`, referência original `y43sevgrsphwTwAd`.
- Mapear as seis chamadas nos nós Execute Workflow para esses dois flows locais e configurar suas APIs/credenciais. Os JSONs desses subworkflows não acompanham o arquivo principal.
- Adaptar a eventual transferência comercial para MOCCHI e validar as respostas reais dos provedores.

Ter importado os 62 nós não comprova que BTV, KSYS, IA e todas as ramificações estejam operacionais. A ativação é bloqueada enquanto as dependências conhecidas estiverem ausentes.

## Exportação

- **Exportar:** pacote `jrc-flows/1` para flows nativos ou `jrc-flows/2` para workflows avançados. O v2 contém as configurações JRC e o workflow com `nodes` e `connections`.
- **Exportar para n8n:** definição do workflow avançado com a estrutura n8n. Preserva os parâmetros importados e as alterações feitas no editor. IDs locais de subworkflows e vínculos às caixas/equipes precisam ser remapeados em outro ambiente. Credenciais do n8n devem existir na instância de destino.
- As chaves digitadas nos campos protegidos de Configurações são criptografadas e não entram na exportação nem na duplicação. Valores escritos diretamente dentro de código/cabeçalhos no próprio JSON continuam fazendo parte do arquivo exportado.
- Salve antes de exportar. A extensão é `.json` e o MIME é `application/json`.

## Caixas e canais

O mesmo evento de mensagem recebida é usado para caixas API, WhatsApp, e-mail, Instagram e Facebook já integradas ao JRC. A saída reutiliza o serviço de envio do canal. Conectar um flow não cria a integração do canal: credenciais, número/página, permissões, janelas de atendimento e restrições do provedor continuam sendo exigidas. Esta homologação usa caixa API local; não foi realizado envio real pelos quatro provedores externos.

## Implantação do módulo

Além do procedimento em `LEIA-ME-FLOWS.md`, aplique `20260916140000_add_workflow_engine_to_jrc_flows.rb` e construa `services/flows-sandbox/Dockerfile`. O exemplo `services/flows-sandbox/compose.example.yml` deve ser integrado à rede do JRC. Não publique a porta do sandbox.

Configure em Rails e Sidekiq `JRC_FLOWS_SANDBOX_URL=http://flows-sandbox:8080/` e `JRC_FLOWS_SANDBOX_TOKEN` aleatório com pelo menos 32 caracteres. O sandbox recebe somente esse token. Preserve `SECRET_KEY_BASE`, usado para proteger os workflows e credenciais armazenados. Gere os assets e reinicie web/Sidekiq. Nenhuma dependência n8n foi instalada no servidor.

No ambiente local entregue, o Compose permanece em `local/flows.compose.yml`, com banco e volumes próprios. Os arquivos locais de ambiente, tokens, JSONs recebidos e dados de teste não entram no ZIP do código.

## Evidências de validação

- 18 verificações com Rails, banco e sandbox reais: importação, round-trip do JSON Jade, dependências, expressões, interrupção de loop, criptografia, Redis e ações de contato, nota, status, lead e atividade.
- 6 verificações adicionais: subworkflow local, recursão direta, contrato de IA com fixture, interrupção do Playground antes de chamada externa, bloqueio de endereço privado e tratamento de erro.
- 5 testes automatizados do sandbox, executados em container sem rede e somente leitura.
- API + Sidekiq: importação, exportação, validação, Playground, duas mensagens com respostas reais na mesma sessão e pausa por intervenção humana.
- Interface: Novo flow com lista rolada, criação avançada, edição e salvamento de código, reconhecimento do arquivo n8n e renderização dos 62 nós.
- IA real, BTV, KSYS e entregas externas por WhatsApp/e-mail/Instagram/Facebook continuam pendentes das configurações citadas acima. O teste de contrato de IA utilizou resposta controlada e não uma chamada paga.

Referências técnicas consultadas: [QuickJS/WASM](https://github.com/justjake/quickjs-emscripten) e [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat).
