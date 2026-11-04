# Revisão 2 — reconstrução visual parcial OIA

Referência: revisão de 04/11/2026 e 23 capturas. Os anexos são especificação e evidência histórica; a autorização para atualizar o repositório NICO comercial e o serviço HML foi dada pelo usuário no chat. Nenhuma imagem original, segredo, telefone, nome pessoal ou identificador operacional legado integra esta entrega.

## Responsabilidades e destino

- BrokerJRCIA: editor compartilhado, definição/versionamento, runtime único de Flow, espera persistida, transporte e transferência canônica.
- JRC Conversas comercial NICO: interface, caixas, catálogo autorizado, operação humana, CSAT e integração com o Broker. Repositório de entrega definido pelo usuário: `ClaudioHideki/jrc-conversas-nico-v12-2-7-comercial-integrado`.
- LAB2: referência dos módulos existentes e da composição consolidada, preservada com histórico Git. Não é o destino desta HML.

A nova branch parte da entrega anterior e incorpora o LAB2 atual. O commit original do destino é ancestral dessa história; não houve reset, substituição de repositório ou merge em main. O domínio indicado é `https://jrcconversas-lab.jrcws.cloud`. O Compose remoto observado ainda usa a imagem anterior, serviços init/Rails/Sidekiq e `.env`, sem PostgreSQL/Redis próprios declarados no Compose. A identificação dos recursos externos, do Broker HML e do contato autorizado continua necessária antes do teste real.

## Comportamento reconstruído

O modelo “OIA — RECONSTRUÇÃO VISUAL HML — PARIDADE PARCIAL” está nos dois pontos de criação do Broker: console e editor embutido no Conversas. Ele cria somente rascunho. Não publica, vincula caixa, seleciona cliente nem envia mensagens automaticamente.

A entrada por conversa verifica expediente, emite no máximo um aviso de fechamento, emite uma saudação e pede idioma. Português e inglês compartilham os departamentos canônicos `sales`, `operations-sp`, `operations-poa` e `finance`. São 2/4/4/3 posições, totalizando 13 posições por idioma e 26 percursos. As posições dos dois idiomas apontam aos mesmos 13 blocos de transferência. Uma posição não equivale obrigatoriamente a uma pessoa distinta: as capturas mostram pessoa compartilhada entre SP e POA.

Cada menu de atendentes tem retorno ao menu de departamentos do mesmo idioma: opção 3 no Comercial, 5 em SP, 5 em POA e 4 no Financeiro. O retorno não passa pela saudação. Idioma, departamento canônico, opção e posição selecionada ficam no estado persistido da execução.

Os menus V2 usam mensagem de erro configurável, limite de tentativas e prazo persistido. Resposta inválida repete apenas o menu atual; o prazo original continua correndo. Eventos de uma espera substituída não consomem tentativas. A versão V2 é explícita; menus históricos mantêm a política original.

**Parâmetros HML, sem equivalência presumida com produção:** nomes sintéticos, 3 tentativas, prazo de 300 segundos por menu, segunda a sexta 08:00–18:00 em America/Sao_Paulo. O fim do expediente está truncado nas capturas; esse horário é dado de teste editável. Sábado e domingo aparecem indisponíveis em IMG_16. Os 13 destinos iniciais estão vazios: selecionar agentes/equipes reais da HML no catálogo e confirmar o expediente antes de publicar.

## Matriz de evidências OIA

APROVADO abaixo vale apenas para o nível expressamente indicado. Nenhum percurso desta revisão foi observado no WhatsApp real até o registro desta matriz.

| Caso | Estado | Evidência / limite |
|---|---|---|
| OIA01 | APROVADO no motor | Idiomas 1/2; contexto e departamentos canônicos nos 26 percursos. |
| OIA02 | APROVADO no motor; BLOQUEADO no WhatsApp | 26 percursos no motor e no PostgreSQL do CI, com exatamente um destino canônico sintético e bot pausado. Não prova atribuição no Conversas remoto. |
| OIA03 | APROVADO no motor | Oito retornos preservam idioma, sem saudação ou transferência. |
| OIA04 | APROVADO no motor | Erro bilíngue inicial, texto original, orçamento persistido, saída exhausted/timeout e espera obsoleta. Política HML explícita. |
| OIA05 | APROVADO no motor; BLOQUEADO no WhatsApp | Fronteiras do horário HML e finais de semana, aviso único e triagem; ordem física depende do transporte real. |
| OIA06 | EM VERIFICAÇÃO | Guardas de saudação, autoatribuição e AgentBot; nova regressão de associação inativa. Requer caixa HML real para prova operacional. |
| OIA07 | BLOQUEADO no WhatsApp | POA 2/3 incluídos nos 26 casos persistidos do CI; corrida humana e fila têm regressões próprias. Atribuição efetiva na caixa HML depende do vínculo real. |
| OIA08 | EM VERIFICAÇÃO | Revalidação por catálogo/revisão já existente; não substituir agente removido silenciosamente. |
| OIA09 | BLOQUEADO operacional | Resposta, nota, prioridade, resolução e reabertura precisam de sessão HML autorizada. |
| OIA10 | EM VERIFICAÇÃO | Correção de idempotência/CSAT nativo e fila Broker; convite HTTPS e resposta por conversa em testes isolados, sem afirmar entrega pelo provedor. |
| OIA11 | EM VERIFICAÇÃO | Escopo por conversa; não deduplicar apenas por telefone. Política de conversa única do cliente ainda não exportada. |
| OIA12 | PARCIAL | Runtime nativo e transporte separados; inventário sem segredos. Dependências legadas não são chamadas pelo modelo; prova de tráfego físico HML pendente. |
| OIA13 | PARCIAL | Inventário visual abaixo; não há exports e vínculos completos de todos os bots. |

## T01–T20

A aprovação automatizada vale para a evidência indicada, não para WhatsApp real nem paridade integral do cliente. O resultado final da imagem do Conversas será fornecido pelo workflow e recibo externo da release.

| Caso | Teste | Automação/CI | HML WhatsApp | Evidência e limite |
|---|---|---|---|
| T01 | Primeira entrada | APROVADO | BLOQUEADO | Uma saudação no motor; roteamento e sessão persistidos nas 26 rotas. |
| T02 | Cada opção | APROVADO | BLOQUEADO | 26 rotas em PostgreSQL no CI; agente canônico sintético e bot pausado. |
| T03 | Entrada inválida | APROVADO | BLOQUEADO | Mensagem bilíngue/localizada, tentativas persistidas e saídas configuradas. |
| T04 | Captura e validação | APROVADO | BLOQUEADO | Gates existentes da plataforma; não prova campos de bots sem export. |
| T05 | Espera e timeout | APROVADO | BLOQUEADO | Menu V2 e captura: prazo, espera obsoleta e fronteiras no motor/CI. |
| T06 | Reinício durante captura | APROVADO | BLOQUEADO | Estado serializado e substituição do worker entre etapas persistidas. |
| T07 | Publicação de versão | APROVADO | BLOQUEADO | Regressões de pinning/versionamento da plataforma no CI. |
| T08 | Eventos repetidos/fora de ordem | APROVADO | BLOQUEADO | Deduplicação/ownership no CI; CSAT não repete o envio nem retoma URA. |
| T09 | Expediente | APROVADO | BLOQUEADO | Fronteiras do horário HML; Rails/Sidekiq reais em teste, UTC preservado. Horário do cliente não confirmado. |
| T10 | Transferência e fila | APROVADO | BLOQUEADO | 26 casos persistidos + regressões de concorrência/incerteza; integração remota e recibos são sintéticos. |
| T11 | Resposta humana | APROVADO | BLOQUEADO | Gates de prioridade humana/transporte do Broker; sem prova de entrega pelo provedor nesta revisão. |
| T12 | Nota/eco/status/histórico | APROVADO | BLOQUEADO | Classificadores e controles de escopo no CI; não iniciam URA como texto de contato. |
| T13 | Retomada explícita | APROVADO | BLOQUEADO | Regressões existentes de retomada; oito retornos OIA no motor sem saudação. |
| T14 | Mídia usada pelo cliente | NAO_EXECUTADO | BLOQUEADO | Plataforma passa gates genéricos de mídia/bytes; formatos específicos dos bots dependem de seus artefatos. |
| T15 | Consulta/ação externa do cliente | NAO_EXECUTADO | BLOQUEADO | CI valida capacidades genéricas; capturas OIA não demonstram contrato ERP. |
| T16 | Isolamento e permissões | APROVADO | BLOQUEADO | 1662 testes de integração incluem escopo, revogação e IDs locais coincidentes; testes de interface preservados. |
| T17 | Reconexão do número HML | BLOQUEADO | BLOQUEADO | Canal indicado não pertence à organização da sessão disponível; número/contato autorizados ainda não identificados. |
| T18 | Sem serviços legados | APROVADO | BLOQUEADO | Modelo/fixture rodam no Broker sem chamadas Typebot/Bridge/Budibase. Prova de tráfego da HML integrada pendente. |
| T19 | Interfaces e papéis | APROVADO | BLOQUEADO | Criação em rascunho nas duas interfaces; 94 testes de UI do Conversas. Papéis reais no ambiente integrado pendentes. |
| T20 | Regressões e imagem final | NAO_EXECUTADO | BLOQUEADO | Broker: CI completo e imagens publicados. Conversas: três gates e smoke da imagem final serão registrados no recibo da release. |

## Inventário visual de bots

IMG_22 exibe 11 linhas e contador de 15 bots: Demo CRF-SP, dois Simuladores CRF-SP, Homologação CRF-SP, OIA Simulação, OIA Logística, CRF-SP, Íris, JRC Demo, Bot Image Demo e Teste Sistêmico. OIA Simulação está na conta 3 e OIA Logística na conta 2 da instância OIA. CRF-SP/Íris aparecem na conta 2 e Teste Sistêmico na conta 3 da instância CRF. O contador não permite identificar as quatro linhas ausentes. IDs locais coincidentes entre instâncias não representam identidade compartilhada. O inventário sanitizado não replica SID nem ID de AgentBot sem evidência correspondente.

IMG_23 mostra nove linhas e contador de 15 instâncias ativas/zero inativas. Não demonstra o inventário completo. O vínculo Flow novo deve ser conferido por origem, organização Broker, integração, conta, caixa, versão, revisão de catálogo e estado. O webhook de transporte não é o callback do AgentBot nem o binding do Flow.

OIA tem reconstrução visual parcial. CRF-SP, Íris e demais bots permanecem **BLOQUEADOS_POR_EXPORT/CONFIGURAÇÃO** para paridade. Saudações repetidas, cascatas de atribuições e reaberturas indevidas observadas no legado não são requisitos a reproduzir.

## Pendências externas

Export publicado dos bots e configurações legadas específicas; correspondência completa de caixas/agentes/equipes; expediente e exceções confirmados; regras de CSAT/etiquetas; origem do Broker HML; isolamento do banco/Redis/armazenamento do serviço indicado; conta/caixa/número e contato autorizados. Avançar build e testes isolados não autoriza usar dados, destinos, credenciais ou números produtivos como substitutos.

## Evidência Broker confirmada antes do congelamento

Fonte `2d30a5a544aa0eae12c208867e4912c369626787`; [CI completo aprovado](https://github.com/ClaudioHideki/BrokerJRCIA/actions/runs/41856020646). Foram 4015 testes unitários/contratos/HTTP e 1662 de integração; a suíte web de 832 testes é subconjunto e não deve ser somada. O arquivo de handoff passou 59 casos, incluindo os 26 OIA; CSAT Broker passou dez casos de transporte/upgrade. As imagens API/web foram publicadas no run 41858209012. O vínculo real continua bloqueado: o canal fornecido não foi encontrado na única organização disponível na sessão; nenhuma das duas caixas conectadas foi escolhida como substituta.
