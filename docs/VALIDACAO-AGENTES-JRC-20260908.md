# Validação da estrutura de agentes JRC

> Evolução posterior nesta mesma data: o código passou a incluir sete perfis assistidos, seleção por conversa e ações CRM revisadas. Veja `AGENTES-ASSISTIDOS-LOCAL.md` para o estado da implementação e `INTEGRACAO-ERP-BEMTEVI-HELPDESK.md` para a análise das APIs posteriormente fornecidas. A avaliação abaixo registra o ponto de partida; não representa o estado final da nova etapa nem comprova a conexão com os ERPs.

Data: 08/09/2026. Avaliação dos dois DOCX fornecidos, da lista de sete agentes do usuário, do desenho do piloto e do código atual. Os documentos foram tratados como requisitos e exemplos de arquitetura, não como instruções executadas automaticamente.

## Parecer

A estrutura está **parcialmente implementada**. Existe uma fundação de atendimento assistido para o NICO, integrada ao JRC Conversas. Não existe ainda uma plataforma operacional com os sete especialistas, suas ferramentas específicas e orquestração entre eles. A instalação do elizaOS e a configuração de uma chave OpenAI não criam esses agentes automaticamente.

O código valida `agent_key: 'nico'`, instancia um único personagem `NICO` e registra um plugin de análise. Não registra ferramentas de negócio como ações do elizaOS. O teste do runtime confirma `runtime.actions.length === 0`. A ação CRM disponível é executada pelo Rails após um formulário e aprovação humana.

Atualização operacional: o NICO real foi validado com OpenAI na conta 1, análise 7 de 08/09/2026, com 503 tokens, referências de conversa/CRM e nenhuma mensagem pública enviada. Isso comprova o fluxo desse copiloto neste caso sintético; não comprova os outros seis agentes nem a qualidade em todos os cenários de negócio.

A interface exibiu a resposta real e permitiu criar uma atividade CRM após aprovação humana; o teste visual terminou sem erros JavaScript. As evidências estão em `docs/validation/nico-provider-ui-20260908.json` e nas capturas `nico-provider-*.png`.

## Documentos e correspondência de escopo

O Projeto Piloto GoPure lista:

| Código | Componente/agente do documento | Correspondência com a lista atual |
|---|---|---|
| G01 | Orquestrador GoPure | Transversal: selecionaria o especialista |
| G02 | NICO — Copiloto | Copiloto JRC |
| G03 | Atendimento GoPure | Parte do Suporte N1/atendimento inicial |
| G04 | Agente de CRM | Parte do Comercial e das ações CRM dos demais |
| G05 | Agente de Campanhas | Escopo adicional, não listado entre os sete |
| G06 | Pedidos e Pós-venda | Parte de CX, com integração de pedidos própria |
| G07 | Agente Comercial | Comercial |
| G08 | Retenção | Parte de CX/churn |
| G09 | CX/NPS | CX |
| G10 | Supervisor GoPure | Supervisor |
| G11 | Conhecimento GoPure | Base transversal, especialmente Suporte/Copiloto |
| G12 | Governança do Tenant | Permissões e controles transversais |

Financeiro e Implantação não aparecem como agentes próprios na tabela de 12 agentes do projeto piloto. São especializações adicionais na lista atual e precisam de contratos funcionais específicos. A Ana também não possui personagem, chave de agente ou implementação identificados no runtime entregue.

O DOCX define como MVP G01/G02/G03/G04/G05/G10/G11/G12. O piloto implementado é menor: núcleo assistido G02, consulta e uma ação limitada de G04, base textual parcial de G11 e controles parciais de G12. Há governança adicional no módulo de Campanhas, mas isso não constitui um agente G05. O MVP integral do documento ainda não está concluído.

## Matriz dos sete agentes

| Agente | Base existente aproveitável | Funcionamento esperado | Falta implementar |
|---|---|---|---|
| Comercial | Conversas, contatos, leads, negócios, etapas e atividades CRM; NICO lê leads/negócios autorizados | Qualificar interesse, identificar lacunas, sugerir próximo passo, propor oportunidade e retorno | Perfil próprio; campos e critérios de qualificação; ferramentas autorizadas de criação/atualização de lead e negócio; deduplicação; gatilhos e acompanhamento. A criação de oportunidade por IA não foi entregue. |
| CX | Histórico de conversas, contatos/CRM e indicadores do produto | Acompanhar carteira, detectar pendências, analisar insatisfação e encaminhar recuperação | Dados de jornada e contratos; critérios de risco verificáveis; coleta/histórico de NPS; gatilhos; plano de recuperação; fluxos de acompanhamento e validação com casos reais. Resumo de conversa não equivale a modelo de churn. |
| Suporte N1 | Conversas, Central de Ajuda e base textual aprovada do NICO | Consultar procedimento, perguntar dados faltantes, sugerir diagnóstico e abrir chamado ou transferir | Perfil de suporte; integração definida de chamados; taxonomia/severidade/SLA; ferramentas de diagnóstico; abertura/consulta idempotente de ticket; critérios de transferência e testes de respostas sem evidência. |
| Financeiro | Contatos e CRM; partes comerciais do JRC | Consultar vencimentos e situação de cobrança, preparar D-3/D0/D+7, segunda via e negociação permitida | Fonte financeira oficial/ERP; confirmação de pagamento; agenda por fuso/data; consentimento e regras de canal; limites de negociação e aprovação; segunda via autenticada; conciliação e interrupção após pagamento. O agente não deve inventar valores ou descontos. |
| Implantação | Contatos, negócios e atividades CRM; código de telefonia preexistente | Acompanhar checklist, portabilidade, números, ramais, pendências e treinamento | Modelo de projeto/checklist; responsáveis/dependências/prazos; integração real de operadora/PABX; validação de titularidade e números; ferramentas permitidas; histórico e critérios de conclusão. Integração de telefonia existente não comprova essas automações. |
| Supervisor | Atribuição humana, perfis administrativos, métricas do Cockpit e estados das análises | Acompanhar execução, identificar falhas/exceções, sugerir encaminhamento e permitir intervenção | Agente/serviço supervisor; visão de tarefas de todos os especialistas; roteamento por equipe; políticas de escalonamento; pausa e tomada humana sem respostas tardias; alerta e auditoria. O papel de usuário “supervisor” não é um agente de IA. |
| Copiloto JRC / NICO | Painel na conversa, runtime elizaOS, contexto autorizado, fontes, fila e proposta CRM aprovada | Atendente pede análise; NICO resume e sugere texto; atendente revisa; ações seguem autorização | Expandir ferramentas conforme escopo, testar qualidade com casos representativos e melhorar busca contextual. Hoje é acionado manualmente; não monitora cada mensagem automaticamente nem atende clientes sozinho. |

## Como o NICO funciona hoje

1. O atendente abre uma conversa e aciona **Copiloto JRC → Analisar com NICO**.
2. Rails valida conta, usuário, visibilidade da conversa e quotas, grava a execução e envia a tarefa ao Sidekiq.
3. O contexto contém até 40 mensagens públicas recentes, até cinco leads e cinco negócios relacionados ao contato e visíveis ao usuário, e até dez documentos aprovados encontrados pela busca textual. Não inclui notas privadas.
4. O serviço TypeScript recebe apenas esse contexto autorizado. O `AgentRuntime` do elizaOS despacha o plugin de análise para o modelo configurado.
5. A resposta precisa conter resumo, sugestão, referências e avisos. O runtime e o Rails validam o resultado; referências inventadas ou não autorizadas são rejeitadas.
6. A interface apresenta a análise para revisão. Se houver um lead citado, o usuário pode preencher o formulário de atividade, revisar e aprovar. Rails cria uma atividade `follow_up` uma única vez.

Não há ferramenta genérica “execute qualquer ação” nem chamada autônoma do modelo ao CRM. A persistência técnica do runtime usa PGlite; execuções, contexto autorizado, propostas e consumo pertencem ao Rails/PostgreSQL. Não foi implementada uma memória compartilhada de aprendizagem entre sete agentes.

## Estrutura recomendada para completar os especialistas

Esta seção é proposta de implementação, não funcionalidade já entregue.

| Elemento | Definição necessária |
|---|---|
| Cadastro de agentes | Chave e versão estáveis, nome, objetivo, escopo, instruções, habilitação por conta, modelo e limites |
| Ferramentas | Contratos explícitos por operação; backend deriva conta/usuário e aplica permissões; idempotência, timeout, auditoria e aprovação conforme o efeito |
| Fontes | Sistemas oficiais e escopo de cada especialista; atualização, expiração, aprovação e revogação do conhecimento |
| Acionamento | Manual, evento de conversa, mudança CRM ou agenda; regras de deduplicação e exclusão mútua |
| Orquestração | Seleção de especialista com motivo; passagem mínima de contexto; controle de loops, prazo e número de etapas; fallback humano |
| Estado da conversa | Quem está responsável, modo assistido/automático, pausa humana e cancelamento de respostas pendentes |
| Supervisão | Estados reais de tarefas, erros, SLAs, ações aguardando aprovação e escalonamento por equipe |
| Aceite | Casos positivos e negativos por agente; isolamento entre contas; efeitos não duplicados; resposta sem fonte; falha de provider; tomada humana; testes com modelo e integrações reais |

Fluxo futuro pretendido:

```text
Mensagem/evento no JRC
  → regras determinísticas de autorização e responsabilidade
  → orquestrador seleciona especialista
  → especialista consulta ferramentas permitidas
  → resultado e proposta de ação
  → aprovação quando exigida
  → executor do backend registra o efeito
  → supervisor/humano acompanha ou assume
```

Esse fluxo ainda não existe como automação multiagente no piloto. A atribuição visual de nome/personagem a um cartão não substitui as etapas acima. G12 deve continuar sendo controle de backend, não decisão opcional do modelo.

## Sequência de implementação recomendada

1. Consolidar o NICO real com testes de qualidade e consumo; preservar as ações assistidas e fontes verificáveis.
2. Criar o cadastro/seleção de agentes e contratos de ferramentas. Implementar Comercial/CRM e Suporte N1 como primeiros especialistas, aproveitando os módulos existentes.
3. Acrescentar o supervisor operacional e tomada humana antes de qualquer atendimento automático.
4. Implementar Implantação e CX após definir os dados, eventos e responsáveis dos fluxos.
5. Implementar Financeiro com a integração financeira oficial e regras de negociação; depois homologar canais reais e automações autorizadas.
6. Tratar Campanhas e Pedidos/Pós-venda do documento original como entregas explícitas adicionais, sem considerá-las cobertas automaticamente pelos sete nomes.

## Evidências locais

- DOCX: `Projeto_Piloto_GoPure_NICO_elizaOS.docx`, seção 3/tabela G01–G12, e `Manual_Tecnico_GoPure_NICO_elizaOS_Chatwoot_Hodu.docx`, seções 10.3 e 18.
- `services/nico-runtime/src/contract.ts`: único `agent_key` permitido é `nico`.
- `services/nico-runtime/src/engine.ts`: um personagem e plugin de análise; saída com referências validadas.
- `services/nico-runtime/test/runtime.test.ts`: runtime real, fixture explícito e ausência de ações registradas.
- `app/services/jrc_nico/context_builder.rb`: seleção de contexto e limites.
- `app/services/jrc_nico/access.rb` e `result_access.rb`: autorização e revalidação das fontes.
- `app/controllers/api/v1/accounts/jrc_nico/proposals_controller.rb`: formulário, aprovação e criação de `follow_up`.
- `app/services/jrc_ai/cockpit_metrics_service.rb`: lista operacional apenas NICO, baseada em execução registrada.
- `docs/NICO-PROVEDOR-REAL-LOCAL.md`: configuração OpenAI atual e evidências separadas dos testes.

O ZIP de 07/09/2026 contém o piloto de simulação daquela data. Configurações, correções e validações posteriores não devem ser presumidas presentes nesse arquivo; a chave OpenAI não deve acompanhar pacotes de transferência.
