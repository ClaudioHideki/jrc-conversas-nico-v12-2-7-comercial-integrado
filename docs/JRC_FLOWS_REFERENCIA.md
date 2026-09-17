# Referência do vídeo e adaptação ao JRC

Fonte fornecida: [A IA que ATENDE sua ligação e conversa por voz — Astra Online](https://www.youtube.com/watch?v=vr8u9EQUkeE). O link original começa em **14:04**, durante a montagem de um chatbot. O levantamento foi feito a partir da página e da transcrição disponibilizada no YouTube; os tempos abaixo são aproximados. O vídeo demonstra outro produto, não o código do JRC.

## Contexto por trecho

| Trecho | Ideia apresentada | Aplicação nesta entrega |
|---|---|---|
| [00:00–07:00](https://www.youtube.com/watch?v=vr8u9EQUkeE&t=0s) | Chatbot responde a eventos de conversa; sequência programa contatos; workflow automatiza eventos; voz usa telefonia/IA em tempo real. | Tipos no catálogo; chatbot, sequência e workflow executáveis; voz explicitamente indisponível. |
| [07:00–11:00](https://www.youtube.com/watch?v=vr8u9EQUkeE&t=420s) | Caixas, gatilhos, palavra-chave, horários, conteúdo e variáveis. | Configurações por caixa, dias/fuso, mensagens e mídia por URL, variáveis. |
| [11:00–19:00](https://www.youtube.com/watch?v=vr8u9EQUkeE&t=660s) | Menu 1/2, escolha de caminho, atribuição, teste e ativação; interrupção por humano e reinício. | Modelo Suporte/Comercial, saídas nomeadas, atribuição, playground e controles de execução. |
| [20:00–23:00](https://www.youtube.com/watch?v=vr8u9EQUkeE&t=1200s) | Esperas entre ações. | Espera fixa persistida. Espera aleatória não incluída. |
| [23:00–34:00](https://www.youtube.com/watch?v=vr8u9EQUkeE&t=1380s) | Status, etiquetas, bot, CRM, captura de resposta, contato, notas e outras ações específicas. | Status, etiquetas, captura/timeout, contato, nota, atribuição, lead, etapa e atividade. SLA, atributos arbitrários e “ghost call” não incluídos. |
| [36:00–37:00](https://www.youtube.com/watch?v=vr8u9EQUkeE&t=2160s) | Botões, listas e templates oficiais de WhatsApp. | O menu do modelo usa texto e resposta numérica. Não foi implementado um editor de mensagens interativas/templates. |
| [37:00–59:00](https://www.youtube.com/watch?v=vr8u9EQUkeE&t=2220s) | Provedor/modelo, prompt, conhecimento, ferramentas, subagentes e modo de conversa da IA. | Reaproveitamento do Nico por delegação com objetivo e permissões. Não há editor de subagentes/RAG/ferramentas por grafo. |
| [59:00–1:04:00](https://www.youtube.com/watch?v=vr8u9EQUkeE&t=3540s) | Sequência, espera, interrupção na resposta e inscrição por conversa/CRM. | Sequência manual, início por etapa e interrupção individual. Não inclui o mesmo painel de inscrição dentro da conversa do produto demonstrado. |
| [1:05:00–1:09:00](https://www.youtube.com/watch?v=vr8u9EQUkeE&t=3900s) | Workflow por evento, recorrência e webhook; automações relacionadas a campanhas. | Gatilhos de conversa, etiqueta, etapa e recorrência direcionada; webhook de saída e API autenticada de início. Não há gatilho público genérico de webhook de entrada nem integração de inscrição automática com campanhas. |
| [1:09:00–final](https://www.youtube.com/watch?v=vr8u9EQUkeE&t=4140s) | Agente de voz com conexão, provedor, voz/modelo, ferramentas, duração e transferência; demonstração de agenda. | Levantamento para evolução. Não foi conectado um provedor de voz, criado agendamento clínico ou reproduzida essa demonstração. |

## Como pensar o flow da JRC

Cada caminho precisa responder a quatro perguntas: **qual evento inicia**, **qual informação é necessária**, **qual ação pode ser executada** e **quando uma pessoa assume**.

Um chatbot de atendimento começa com identificação transparente do assistente, captura a intenção e encaminha. Um flow comercial captura interesse, associa o lead à conversa, registra contexto e entrega ao responsável. Uma sequência acompanha uma conversa específica e cancela a espera quando há resposta. Um workflow executa uma ação em reação a mudanças operacionais, como entrada em uma etapa do funil.

Um flow de JRC não precisa repetir toda a automação existente. A criação de lead deve usar o serviço atual de conversa; a IA deve usar o Nico e suas permissões; a atribuição deve usar os agentes/equipes da conta; a comunicação deve usar o canal já conectado.

## Exemplos para montar no editor

**Recepção:** Início → mensagem de boas-vindas → captura de `setor` → escolha de caminho → atribuição. Direcione a saída alternativa e o tempo limite para uma pessoa. É o modelo do trecho inicial solicitado.

**Qualificação comercial:** Início → pergunta sobre interesse → captura de `interesse` → criar lead → nota privada com `{{interesse}}` → atribuir ao comercial. O contato não precisa repetir ao atendente o dado já coletado.

**Dados de cadastro:** Início → perguntar nome → capturar `nome` → editar contato/nome com `{{nome}}` → próxima pergunta ou atribuição. Conecte explicitamente cada saída de tempo limite. Validações de e-mail/telefone continuam sendo as do cadastro.

**Retorno de proposta:** sequência manual → aguardar → mensagem de acompanhamento → encerrar. Configure o prazo e a interrupção por resposta; o canal continua aplicando suas regras de envio. Para iniciar por CRM, mude o tipo para workflow/sequência e selecione gatilho/etapa.

**Nico:** Início → Atendimento Nico, com objetivo delimitado e apenas as autorizações necessárias. O fluxo termina ao delegar; dali em diante valem os controles já existentes do Nico. Não existe neste motor retorno automático de uma ferramenta do Nico a uma saída do grafo.

**Integração externa:** evento → condição → webhook com dados selecionados → nota ou encerramento. O receptor deve validar a origem conforme sua implantação e deduplicar pelo identificador recebido. Esta versão não oferece armazenamento seguro de segredos por bloco nem editor de cabeçalhos de autenticação.

## Evoluções que exigem integrações próprias

Para chegar à demonstração de voz seriam necessários, no mínimo, contrato com o adaptador de chamadas do JRC, streaming bidirecional de áudio, sessão de IA em tempo real, eventos de chamada/transferência, credenciais por conta, limites de duração, transcrição e ferramentas autorizadas. A existência de Webphone/WhatsApp Calling no código não demonstra que esses contratos já estejam ligados ao motor de Flows.

Outras diferenças relevantes: editor de templates e botões de WhatsApp, gatilhos de contato e campanha, endpoint autenticado de webhook de entrada com mapeamento de payload, agendador em data específica, SLA, campos personalizados, registro de sequência diretamente no painel de conversa e grafo de agentes/ferramentas.

A implementação entregue cobre a base do editor e da execução de automações de atendimento do JRC. Este documento distingue o que o vídeo demonstra do que o código realmente implementa.
