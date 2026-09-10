# NICO — assistente operacional do JRC

Atualização aplicada em 09/09/2026 na instalação `lab-gopure-nico-20260908/JRC-Conversas`, em http://localhost:3107. Esta edição substitui a proposta técnica anterior e descreve o que está implementado, testado e ainda depende de homologação externa.

**Revalidação do fluxo natural:** o histórico enviado pelo operador expôs falhas de continuidade, vínculo entre contato e conversa, diagnóstico de capacidade e fuso de agendamento que não estavam cobertas pelos 139 testes anteriores. Consulte [a auditoria de fluidez](NICO-AUDITORIA-FLUIDEZ-20260909.md) e suas evidências antes de considerar homologado o atendimento operacional completo. As correções descritas nessa auditoria ainda são propostas.

## Usar agora

Abra o mascote do NICO no canto da tela. A conversa privada com o operador persiste ao navegar entre módulos. Digite, por exemplo:

- “Crie um contato chamado Mariana, telefone +5511999999999.”
- “Crie um lead para esse contato.”
- “Agende uma tarefa de retorno para esse lead amanhã às 10h.”
- “Mostre minhas atividades e as conversas pendentes.”

Os exemplos são instruções de uso, não registros criados automaticamente. O NICO pergunta pelos dados ausentes, resolve recursos nas consultas autorizadas e apresenta uma prévia das alterações. Confira os dados e confirme. O comprovante usa o resultado real do sistema, com ID e acesso ao módulo. Datas e horas devem ser conferidas na prévia; o planejamento recebe o fuso da conta.

### Atender vários clientes

1. Clique em **NICO atender clientes** no cabeçalho do assistente.
2. Selecione as conversas, descreva o objetivo e escolha a duração (até oito horas).
3. Autorize criação de lead apenas se desejar. Revise a prévia e confirme.
4. Acompanhe os estados e resumos em **Atendimentos do NICO**.
5. Use **Assumir atendimento** para retomar. Uma resposta pública do humano ou atribuição a outro atendente também interrompe o NICO; notas privadas não interrompem.

Cada cliente tem histórico próprio. O NICO se apresenta como assistente virtual, qualifica a necessidade com o objetivo autorizado e devolve a conversa ao humano quando faltam informações confiáveis ou surge uma falha. O processamento continua no servidor enquanto a delegação estiver válida, mesmo com o painel recolhido. Uma mensagem já transmitida ao canal não pode ser desfeita pela retomada.

### Conhecimento comercial

No ícone de livro, administradores podem cadastrar orientações. Para usar um documento com clientes, marque **uso em respostas a clientes**, salve e aprove aquela versão. Alterar o texto ou esse escopo invalida a aprovação anterior. Documentos existentes permanecem internos por padrão. Mensagens privadas do operador e notas internas não entram no contexto do cliente.

O contexto comercial inclui mensagens públicas daquela conversa, documentos públicos aprovados e campos públicos do catálogo. O NICO não deve inventar preços, disponibilidade, descontos ou compromissos. As análises dos sete especialistas continuam disponíveis ao abrir uma conversa.

### Voz e interface

O botão de microfone inicia a captura sob comando do operador, por no máximo 60 segundos e 4 MB. O áudio é enviado ao provedor configurado na conta para transcrição. O texto volta ao campo de pedido, editável, e só vira uma tarefa quando o operador envia. Recolher o painel, trocar de conta, cancelar ou iniciar uma chamada interrompe a captura. A leitura das respostas em voz alta é opcional.

O mascote recolhido sinaliza sugestões sem abrir o painel ou roubar foco. Em telas largas, a conversa ocupa uma coluna lateral; em telas médias, uma área abaixo do módulo; em telas pequenas, uma área própria com botão para recolher. O menu móvel foi corrigido para não reservar uma coluna vazia quando fechado.

## Cobertura implementada

O catálogo contém **48 ações**, filtradas pelas permissões do operador e executadas pelas regras existentes do JRC. A autorização é conferida novamente ao executar.

| Área | Ações disponíveis |
| --- | --- |
| Contatos | Buscar, criar e atualizar, com validação de telefone/email e detecção de duplicidade. |
| Conversas | Listar e ler, responder ou criar nota, alterar status, prioridade, responsável, equipe e etiquetas; delegar e retomar atendimentos. |
| CRM | Consultar/criar/atualizar leads, converter lead, consultar/criar/atualizar/mover negócios, consultar funis, agendar/alterar/concluir atividades. |
| Produtos e propostas | Consultar catálogo; criar/alterar proposta, adicionar item, solicitar/aplicar aprovação conforme papel, enviar e abrir PDF. |
| Campanhas | Consultar/criar/alterar rascunhos, solicitar revisão, aprovar, lançar/pausar/retomar/cancelar, consultar relatório e exportar pelo módulo existente. |
| E-mail | Preparar e enviar e-mail pela caixa configurada, usando a API autenticada do operador. |
| Ligações | Consultar disponibilidade, discar para contato e controlar chamada SIP; iniciar/controlar WhatsApp Calling pelas capacidades existentes. |
| Vídeo | Abrir a sala já configurada para o operador. |
| Cockpit e relatórios | Resumo operacional de conversas visíveis e atividades, relatório/exportação de campanhas e navegação aos módulos. |
| Configurações | Consultar condições dos canais, alterar a própria disponibilidade e abrir configurações autorizadas. |

O NICO usa uma sessão por conta/usuário, comandos persistidos com chave de idempotência, ferramentas de parâmetros limitados e comprovantes. O modelo propõe; Rails valida e executa. Ações que dependem da aba usam uma autorização de curta duração, adquirida por uma única aba. Uma resposta incerta de canal fica identificada como incerta e não gera reenvio automático.

Cotas de execuções e tokens incluem reservas em andamento. Falhas de provedor sem contabilização mantêm reserva conservadora. O runtime limita concorrência (padrão de três, máximo configurável de oito), e os atendimentos têm controle de versão para descartar respostas antigas após retomada humana.

## BEMTEVI e Help Desk

As consultas ERP foram retiradas do fluxo do NICO, das rotas ativas e da inicialização do pacote. O contexto novo não busca essas fontes. O serviço ERP foi desativado; histórico e estrutura de dados anteriores foram preservados, sem apagar credenciais ou bancos. Nenhuma consulta nova depende dele.

## Validação executada

- **105 testes Rails passaram**, incluindo NICO, isolamento de conta/permissão, idempotência, concorrência, retomada durante geração, bloqueio de mensagem enfileirada após ação humana, escopo do conhecimento, voz e regressão de atribuição/construção/envio de mensagens.
- **19 testes Vue/JavaScript passaram**, incluindo autenticação das APIs, ações do navegador/módulos e ciclo de captura de voz.
- **15 testes do runtime passaram**, incluindo elizaOS, limites, autenticação, concorrência, cancelamento, contrato estruturado e transcrição.
- Build de produção dos assets locais e build TypeScript concluídos. Revisão visual em 360, 1680 e 1920 px, incluindo navegação móvel, documentada em `validation/nico-interface-20260909.json`. O painel usa coluna lateral a partir de 1920 px para preservar a largura da conversa do cliente.
- Provedor real: contato **49**, lead **13** e atividade **7** criados com dados fictícios. Três clientes fictícios receberam respostas independentes nas conversas **11, 12 e 13**. Todos os atendimentos foram devolvidos ao operador ao terminar. Evidência: `validation/nico-operational-e2e.json`.
- Voz com provedor real: áudio sintético “Crie um contato de teste.” foi transcrito corretamente, sem criar comando e sem ativar o microfone do usuário. Evidência: `validation/nico-voice-e2e.json`.
- Pela interface, uma nova solicitação criou o contato fictício **50**, mostrou o comprovante e abriu o cadastro correto. O histórico persistiu entre módulos e após recarregar. Resumo dos testes: `validation/nico-implementation-tests-20260909.json`.

Os testes de atendimento usaram uma caixa API exclusiva de homologação, sem webhook, e clientes fictícios sem telefone/email. Eles comprovam o fluxo interno e a geração real; não comprovam entrega em WhatsApp, e-mail ou telefonia externa. Os registros QA foram mantidos para inspeção.

## Limites e próximos aceites externos

- A conta local não tem ramal SIP, caixa de e-mail, WhatsApp Calling nem sala de vídeo configurados. As ações estão conectadas aos módulos, mas chamadas, envios externos e abertura de sala real exigem esses canais e um destino de homologação autorizado.
- O microfone físico, qualidade em ambiente ruidoso, vozes instaladas e comportamento em cada navegador ainda precisam de validação com o operador. Não há escuta contínua nem atendimento de voz autônomo ao cliente em uma ligação.
- Relatórios avançados, filtros arbitrários, públicos/etapas complexas de campanhas, configuração de credenciais, gestão de acessos e ações destrutivas continuam nas telas próprias. As 48 ações não representam automação irrestrita de todos os controles existentes.
- Não há provisionamento de salas novas de vídeo. O módulo abre a sala configurada.
- O cancelamento impede novas respostas sob controle do JRC, mas não desfaz transmissão externa já iniciada. Estado interno de sucesso não substitui recibo de entrega/leitura do provedor.
- O atendimento comercial deve ser homologado com o conteúdo público aprovado, produtos e regras reais da empresa antes de delegar clientes reais.

## Operação local

Com Docker aberto, use `scripts/nico-package-start.ps1 -SkipBuild` para iniciar o pacote já compilado, preservando o banco. Para recompilar fontes, execute sem `-SkipBuild`. Esse script aplica migrações e reinicia os processos, necessário porque a instalação usa assets estáticos e cache de classes.

A conta local é `admin@gopure.test`; a senha permanece em `local/nico.env`, e a configuração do provedor em `local/nico-provider.env`. Não publique esses arquivos.

`scripts/nico-package-verify.ps1` executa a regressão em banco isolado. Os scripts `nico-operational-e2e.mjs` e `nico-voice-e2e.mjs` validam integração real e consomem a cota do provedor. Não use o primeiro com conversas reais como dados de teste.
