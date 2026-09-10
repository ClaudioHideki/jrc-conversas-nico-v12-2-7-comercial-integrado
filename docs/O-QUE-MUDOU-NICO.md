# JRC Conversas: o que já existia, o que mudou e como usar

Comparação em 07/09/2026 com a pasta original extraída do ZIP `JRC-V11-CAMPANHAS-PREMIUM-UX-20260904`. A existência de um módulo no código original não significa que todas as suas integrações externas tenham sido homologadas.

Atualização em 08/09/2026: o NICO já completou uma análise real com OpenAI na conta 1. Consulte [a configuração e evidências atuais](NICO-PROVEDOR-REAL-LOCAL.md) e [a matriz dos sete agentes](VALIDACAO-AGENTES-JRC-20260908.md). As descrições de fixture abaixo documentam a entrega e o ZIP de 07/09; não significam que os sete especialistas foram implementados.

## Comparação dos módulos

| Área | O que já existia | Trabalho realizado neste piloto |
| --- | --- | --- |
| Conversas | Caixa de entrada, atribuição, respostas, notas privadas e organização de atendimentos | Integração do painel NICO com a conversa aberta, com autorização por conta e usuário |
| Canais | Conectores de WhatsApp, Instagram, Facebook, e-mail, API, widget e outros | Canal API fictício para homologação; nenhuma conta real de WhatsApp/Instagram conectada |
| Contatos e empresas | Cadastros e organização de relacionamentos | Contexto autorizado desses relacionamentos disponibilizado ao NICO através da conversa/CRM |
| CRM | Leads, negócios, atividades e fluxos de CRM | Proposta de retorno pelo NICO; atividade só é gravada após revisão e aprovação |
| Copiloto JRC | Painel, mascote, orientação contextual e integração de IA legada | NICO assistido por conversa, executado pelo runtime elizaOS, com estados, fontes e histórico |
| Agentes IA e Cockpit | Telas e cartões de agentes/indicadores | Cartão NICO baseado em execução registrada; retiradas afirmações de agentes ativos sem execução correspondente; ajustes de permissões e métricas indisponíveis |
| Provedores de IA | Configuração de provedores e acompanhamento de uso da IA legada | Transporte próprio do NICO, contabilização de tokens e reserva de capacidade; a configuração antiga não é importada automaticamente |
| Conhecimento | Central de Ajuda | Base de conhecimento específica do NICO, com texto em rascunho, aprovação por administrador e invalidação da aprovação após edição |
| Campanhas | Editor, públicos, etapas, agendamento, acompanhamento e listas de bloqueio | Registro de consentimento com evidência/revogação, revisão e aprovação, verificações no envio, isolamento de conta e proteção contra duplicidade |
| Telefonia e vídeo | Módulos de chamadas, webphone, WhatsApp Calling, videoconferência e código de integração Hodu | Revisão da integração existente; nenhuma chamada real homologada neste piloto |
| Administração | Contas, usuários, caixas, permissões, configurações e outras telas do JRC | Aplicação dessas permissões ao NICO; dois ambientes de conta fictícios e um atendente sem acesso ao CRM para testes |
| Operação local | Arquivos de implantação do projeto recebido | Compose de homologação, runtime NICO, configuração local, seed, compilação em volume Linux, scripts de teste, backup e restauração |

## Como usar o NICO

1. Entre em `http://localhost:3107/app/login` como `admin@gopure.test`. A senha fica em `NICO_LOCAL_PASSWORD`, no arquivo `local/nico.env`.
2. Abra **Conversas → Cliente Sintético 1**. A rota direta é `http://localhost:3107/app/accounts/1/conversations/1`.
3. Clique no mascote do **Copiloto JRC**, no canto inferior direito. Dentro de uma conversa habilitada, o painel apresenta **NICO assistido**.
4. No campo **O que deseja analisar nesta conversa?**, escreva, por exemplo: “Resuma o pedido do cliente, indique o que falta perguntar e sugira o próximo passo”.
5. Clique em **Analisar com NICO**. A execução passa por fila, análise e conclusão; também pode falhar ou ser cancelada.
6. Consulte o resultado e abra **Referências utilizadas**. Com um provedor real habilitado, uma sugestão de resposta pode aparecer para revisão e cópia pelo atendente.

O modo atual é **simulação local (`fixture`)**. Ele valida transporte, permissões, contexto e gravação dos resultados; não produz uma análise inteligente de um modelo externo. O aviso de simulação deve permanecer visível. NICO não envia automaticamente a resposta ao cliente.

O contexto inclui até 40 mensagens públicas recentes, CRM permitido ao usuário e documentos aprovados da conta. Notas privadas da conversa não são incluídas. As execuções atuais são restritas à conta e ao usuário que as criou. Uma fonte removida ou cujo acesso foi revogado pode tornar um resultado anterior indisponível.

## Como usar a atividade assistida no CRM

Depois de uma análise que cite um lead autorizado:

1. Expanda **Preparar atividade no CRM**.
2. Escolha o lead, informe o título e a data/hora do retorno.
3. Clique em **Preparar para revisão**. Isso cria a proposta, ainda sem criar a atividade.
4. Confira os dados e marque **Revisei os dados e autorizo criar esta atividade no CRM**.
5. Clique em **Aprovar e criar atividade**. O sistema registra a atividade e informa que nenhuma mensagem foi enviada ao cliente.

A aprovação repetida da mesma proposta não deve duplicar a atividade. A ação disponível nesta etapa é um retorno no CRM; cobrança, negociação, alteração de contratos e outras ações externas não foram implementadas como ferramentas autônomas do NICO.

## Como usar a base aprovada

No painel NICO, o administrador encontra **Base aprovada da conta**. Crie um documento com título e conteúdo, salve o rascunho, confira a versão, marque a autorização e aprove. Somente versões aprovadas entram nas análises. Ao editar, é necessário aprovar novamente.

Esta etapa utiliza texto cadastrado na interface e busca textual. Não foi entregue um importador automático de PDF/DOCX nem uma pesquisa vetorial geral sobre todos os arquivos da empresa. A Central de Ajuda preexistente continua sendo um módulo separado.

## O que mudou no uso de campanhas

O editor existente foi preservado. Estes controles se aplicam ao módulo JRC Campanhas (`jrcCampaigns`), não significam cobertura do módulo legado “Campanhas via Webhook”. Administradores passam a registrar consentimentos com evidência e podem revogá-los. Antes de iniciar, a campanha deve ter uma revisão do conteúdo/público e uma aprovação válida. A aprovação expira em 48 horas; mudanças na configuração exigem nova revisão.

No envio, o sistema reavalia restrições, bloqueios, consentimento, estado da campanha e condições do canal. Campanhas pausadas/canceladas não devem continuar enviando. Também foram corrigidos casos de execução concorrente, falha após aceitação pelo provedor e reenvio indevido quando o resultado anterior é incerto. Esses controles foram testados com transportes simulados; não autorizam um disparo real neste ambiente local.

## O que ainda não foi entregue

- Agentes Comercial, CX, Financeiro, Suporte, Implantação e Supervisor como agentes autônomos separados.
- Orquestração operacional desses especialistas entre si.
- Resposta automática em WhatsApp ou Instagram e homologação dos canais reais.
- Inferência real da OpenAI, qualidade das respostas e custos efetivos do provedor.
- Chamadas reais Hodu/PABX e demais ações externas citadas no projeto conceitual.
- Liberação para produção: há pendências de modernização e segurança do projeto herdado, descritas no relatório de frameworks.

Uma chave válida permite habilitar o modelo do NICO depois de configurarmos provedor, modelo, saída de rede e limites. Ela não cria os demais agentes nem conecta os canais. O arquivo `local/nico-provider.env` foi preparado para receber a chave localmente, mas ainda não é carregado pelo Compose de simulação.

## Validação realizada

- Rails: 62 testes integrados de NICO e campanhas passaram.
- Runtime: compilação e 9 testes passaram com elizaOS/PGlite reais e respostas externas controladas.
- Painel: 6 testes passaram, incluindo a regressão da sessão autenticada.
- API local: login, análises em duas contas, isolamento, restrições do atendente, aprovação idempotente no CRM e ausência de mensagem pública nova passaram.
- Backup/restauração: `pg_dump` concluído e restaurado em banco novo, confirmando duas contas sem alterar o banco da aplicação.
- Interface: teste visual completo aprovado em 07/09/2026, análise 5 em modo fixture. Login, rotas principal e Participantes, análise autenticada e criação de atividade após autorização humana passaram, sem erros de JavaScript. Capturas e resultado em `docs/validation/nico-ui-local.json` e `nico-*.png`.

Evidências: `docs/validation/`. Procedimentos de inicialização: `docs/NICO-HOMOLOGACAO-LOCAL.md`. Pendências de publicação: `docs/superpowers/plans/framework-readiness.md`.
