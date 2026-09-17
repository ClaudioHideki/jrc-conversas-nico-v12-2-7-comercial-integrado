# JRC Conversas — Flows

**Release JRC + Broker (17/09):** [instalação no Dokploy, permissões e aceite](docs/DEPLOY-FLOWS-BROKER.md). Flows fica no JRC Conversas; a conexão com o Broker também é nativa. Integrações externas ficam beta e desligadas por padrão. Os detalhes abaixo registram a evolução do laboratório.

Esta entrega acrescenta a aba **Flows** ao JRC Conversas do ZIP enviado, usando o frontend Vue, a API Rails, o CRM e o Nico existentes. O código não foi instalado no servidor de produção.

## Atualização: motor interno de workflows

A versão atual também importa workflows n8n para edição e execução dentro do JRC, com código isolado, Redis, IA, HTTP e subworkflows. Consulte [o guia do motor interno](docs/JRC_FLOWS_MOTOR_INTERNO.md) para configuração, compatibilidade, testes e pendências específicas da Jade. Não exige URL de webhook nem instância n8n.

## O que está incluído

- Editor visual com blocos, conexões por saída, movimentação, zoom e ajuste à tela.
- Biblioteca de boas-vindas, triagem Suporte/Comercial, qualificação comercial, retorno ao cliente e delegação ao Nico.
- Configurações por caixa, gatilho, palavra-chave, dias, horário, fuso e regras de interrupção.
- Playground que percorre o grafo sem enviar mensagens nem alterar registros.
- Histórico por conversa, rastreio dos blocos, interrupção individual e início manual.
- Importação/exportação JSON, duplicação, rascunho, ativação e pausa.
- Execução no servidor, captura de respostas, espera persistida e recuperação de temporizadores.

**Voz em tempo real não está implementada.** Há um modelo identificado como planejamento, cuja ativação é bloqueada. A telefonia já existente no JRC não equivale ao adaptador de agente de voz demonstrado no vídeo.

## Instalação

Use o fluxo de publicação habitual do JRC, com cópia do banco e uma instalação de homologação para o primeiro uso.

1. Atualize a aplicação a partir deste código, preservando as variáveis de ambiente e os volumes da instalação.
2. Instale as dependências com as versões do projeto: Ruby 3.4.4, Node 24 e pnpm 10.2.0. O pacote inclui o lockfile atualizado. Foram declarados explicitamente `postcss-import` e `sass`, exigidos pela configuração de estilos já existente.
3. No ambiente da aplicação, execute `RAILS_ENV=production bundle exec rails db:migrate`. A migration `20260916120000_create_jrc_flows.rb` cria `jrc_flows` e `jrc_flow_runs`.
4. Gere os assets pelo processo existente, por exemplo `RAILS_ENV=production bundle exec rails assets:precompile`, ou reconstrua a imagem do projeto. Não basta publicar apenas os arquivos Vue.
5. Reinicie web e Sidekiq. Mantenha as filas `default`, `high` e `scheduled_jobs` e o carregamento de `config/schedule.yml`. A recuperação de Flows roda a cada minuto.
6. Entre como administrador da conta e abra **Flows**. Novos flows começam em rascunho.

O pacote contém código-fonte, sem `node_modules`, gems, credenciais novas ou assets compilados. Não é uma imagem Docker pronta. Não substitua a imagem em produção sem aplicar a migration correspondente.

## Primeiro flow: Suporte e Comercial

1. Na biblioteca, escolha **Suporte e Comercial**.
2. Dê um nome e selecione uma caixa de homologação.
3. Abra o bloco de mensagem e adapte a apresentação da JRC.
4. O bloco **Capturar resposta** salva a resposta em `setor`. Configure o tempo limite.
5. O bloco **Escolher caminho** compara `setor`: 1 segue para suporte; 2 para comercial.
6. Nos três blocos de atribuição, selecione as equipes ou atendentes reais, incluindo o destino de resposta desconhecida/tempo esgotado.
7. Em **Configurações**, confira os horários e as regras de atribuição. Caixas com atribuição automática a um atendente podem impedir o início quando “pausar com atendente” estiver marcado.
8. Salve e clique em **Validar**. Corrija cada saída não conectada ou recurso ausente.
9. No **Playground**, teste uma resposta por linha: execute separadamente com `1`, `2`, uma resposta diferente e `__timeout__`.
10. Ative. Envie uma mensagem real de um contato de homologação e confira **Execuções**, a conversa e a atribuição.

A conexão pode ser criada clicando na saída de um bloco e na entrada do próximo, ou escolhendo o destino no painel do bloco. Delete/double click sobre a conexão remove a ligação; as setas do teclado movem o bloco selecionado. **Ajustar à tela** mostra o grafo inteiro.

## Blocos disponíveis

| Bloco | Comportamento |
|---|---|
| Início | Ponto único de entrada; o gatilho fica nas configurações. |
| Enviar mensagem | Texto pelo canal da conversa, com variáveis. |
| Enviar mídia | Busca imagem, áudio, vídeo, PDF ou texto por URL HTTPS; limite de 10 MB, sujeito ao canal. |
| Capturar resposta | Aguarda a próxima mensagem recebida, salva uma variável e possui saída de tempo limite. |
| Escolher caminho | Até dez regras e uma saída alternativa. |
| Condição | Duas saídas: sim/não. |
| Aguardar | Espera persistida de 1 segundo a 7 dias. |
| Salvar variável | Define uma variável da execução. |
| Editar contato | Atualiza nome, e-mail ou telefone com as validações do cadastro existente. |
| Etiquetas | Adiciona ou remove etiquetas existentes na conta. |
| Alterar status | Aberta, pendente ou resolvida. |
| Nota privada | Registra informação interna na conversa. |
| Atribuir atendimento | Atribui equipe/atendente, abre a conversa e encerra o flow. |
| Criar lead | Reutiliza a conversão de conversa em lead do CRM, evitando outro lead para a mesma conversa. |
| Mover no funil | Move o único negócio aberto do contato no funil da etapa escolhida; falha quando a escolha é ambígua. |
| Criar follow-up | Cria atividade do CRM ligada ao lead/contato/conversa, com responsável e prazo. |
| Enviar webhook | POST HTTPS com o conteúdo configurado e identificadores da execução. |
| Atendimento Nico | Delega ao Nico com objetivo, duração e permissões explícitas; encerra o flow. |
| Encerrar | Finaliza a execução. |

**Atribuir atendimento**, **Atendimento Nico** e **Encerrar** não têm saída. Não são aceitos ciclos; modele a conversa com etapas sucessivas de captura. Há limite de 150 blocos, 300 conexões e 200 passos por execução.

Variáveis iniciais: `{{contact.name}}`, `{{contact.email}}`, `{{contact.phone_number}}`, `{{conversation.id}}`, `{{inbox.name}}` e `{{message}}`. Uma captura chamada `interesse` disponibiliza `{{interesse}}`. Os blocos do CRM também podem definir `lead_id` e `activity_id`; o webhook define `webhook_response`.

As comparações ignoram maiúsculas/minúsculas e espaços externos. Operadores: igual, diferente, contém, começa com e preenchido. Não há execução de JavaScript/Ruby dentro das expressões.

## Gatilhos e execução

Chatbots começam por mensagem recebida. Workflow e sequência compartilham o motor e permitem os demais gatilhos:

- conversa criada, reaberta ou resolvida;
- etiqueta adicionada;
- negócio entrando na etapa escolhida, para conversas vinculadas a ele;
- recorrência por intervalo;
- início manual pela aba de execuções/API;
- mensagem recebida, com palavra-chave opcional.

A recorrência recebe de 1 a 100 números de conversas da conta e intervalo entre 1 minuto e 7 dias. A primeira execução é após o intervalo; horários e atribuições continuam valendo. Ela não percorre toda a base nem repõe retroativamente disparos perdidos. Use o número exibido na conversa, não o ID interno do banco.

Só existe **uma execução ativa por conversa**. Se vários flows corresponderem ao evento, o mais antigo tem prioridade. Um chatbot já executado não reinicia em toda mensagem; pode reiniciar após resolução, conforme sua configuração.

A espera de uma sequência pode ser interrompida quando o cliente responde. Uma mensagem pública enviada por pessoa interrompe a execução; as regras também permitem pausar por atribuição a atendente/equipe. Flows não iniciam em conversa já atribuída a outro bot.

Pausar o flow encerra suas execuções em andamento; reativar não as retoma. Edite apenas enquanto pausado. A execução guarda uma cópia do grafo/configurações e há controle de versão para evitar sobrescrever alterações de outra sessão.

Mensagens já entregues não podem ser retiradas. O processamento de envio verifica novamente a autorização e o estado do flow antes de chamar o serviço do canal. WebWidget/API também possuem mecanismos próprios de publicação de mensagens. **Concluído** no histórico significa que os blocos terminaram, não que o provedor confirmou a entrega; consulte a conversa para isso.

## CRM, Nico e integrações

Os blocos de CRM exigem o recurso habilitado na conta. O Nico exige `NICO_MODE=provider`, provedor configurado e habilitação da conta. Sua base de conhecimento e ferramentas continuam sendo administradas no Nico existente. O editor não cria um segundo sistema de IA.

Mídias e webhooks reutilizam `SafeFetch`; o acesso à rede privada segue a política configurada no servidor. URLs não aceitam credenciais embutidas nem substituição de variáveis. O corpo do webhook envia `event`, `flow_id`, `run_id`, `conversation_id` e `data` (texto configurado). O cabeçalho `Idempotency-Key` identifica execução/bloco: o receptor deve honrá-lo para evitar efeito duplicado após falhas ou reinício do processo. A integração não fornece uma garantia distribuída de “exatamente uma vez”.

O playground simula ações externas e não verifica credenciais, disponibilidade de provedor, entrega de mídia ou regras operacionais do CRM. Essas integrações precisam de uma passagem real em homologação.

## API

Base: `/api/v1/accounts/:account_id/jrc_flows`. Exige autenticação de usuário administrador da conta, inclusive para consulta. Agentes comuns não veem a aba.

- CRUD padrão; escrita usa `{ "flow": { "name", "kind", "graph", "settings", "lock_version" } }`.
- `GET /metadata`: caixas, agentes, equipes, etiquetas, etapas e capacidades.
- `POST /:id/activate`, `pause`, `duplicate`.
- `POST /:id/validate_definition` e `simulate`: aceitam o rascunho em `flow`; simulação recebe `responses: []`.
- `GET /:id/runs?before=...`: histórico paginado em 30.
- `POST /:id/start`: `{ "conversation_id": 123 }`, para flow ativo com gatilho manual.
- `POST /:id/stop_run`: `{ "run_id": 456 }`.

Importações usam o formato exportado `jrc-flows/1`. Ao importar em outra conta, selecione novamente caixas e recursos locais. A exportação inclui os textos do flow, não o histórico de conversas.

## Verificação desta entrega

A compilação de produção do frontend passou. Os arquivos novos de Vue/JS passaram no ESLint sem erros; há avisos de chaves dinâmicas de tradução. A sintaxe dos 19 arquivos Ruby novos/alterados foi verificada com Ruby 3.4.1 via WASM. Foram exercitados os serviços reais de validação e simulação em 19 cenários com adaptadores mínimos para as dependências de conta.

**Validação local adicional em 16/09/2026:** ambiente Rails/PostgreSQL/Redis/Sidekiq iniciado em Docker, migration aplicada, seis modelos carregados, login e editor conferidos no navegador. A triagem foi exercitada por mensagens fictícias no canal API: início, espera, resposta 2 e atribuição ao Comercial concluídos pelo worker. Playground e restrição de acesso de atendente também foram conferidos. Foram corrigidos o agrupamento no menu e a serialização da lista de atendentes. Entrega em canais externos, concorrência sob carga, CRM e Nico ainda exigem homologação específica. O build também emitiu avisos do projeto sobre bundles grandes, Browserslist antigo e uma imagem de marca resolvida em runtime.

Roteiro de aceite: verificar acesso de administrador e recusa para agente; criar/editar/duplicar/importar; testar todos os caminhos de triagem; conferir tempo limite e resposta durante espera; interromper e pausar com envio pendente; verificar resolução/reinício; testar lead/etapa/atividade com registros reais; testar Nico habilitado/desabilitado; testar webhook com endpoint de homologação; conferir recorrência e histórico após reiniciar o worker.

Veja [o levantamento do vídeo](docs/JRC_FLOWS_REFERENCIA.md) para o que foi adaptado e o que ainda depende de desenvolvimento.
