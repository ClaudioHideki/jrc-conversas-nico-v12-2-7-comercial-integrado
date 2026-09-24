# Integração JRC Conversas / Broker — continuidade

## Base e escopo desta revisão

Base JRC: `3b4db70dab1f1fe40bc31a45ebd3f6bfa8cfe7d1`.
Base Broker conciliada: `f8e81df271670348201998890b56654b1c95bb0c`.
O Broker remoto foi consultado em 24/09/2026: main em `b352b8c` é ancestral da base conciliada.

Esta revisão acrescenta a adoção de caixas já vinculadas no Broker e recuperação de pareamento assíncrono. Não cria caixas remotas na adoção, não altera webhook nem apaga mensagens. Somente administradores podem adotar; o backend valida contexto, conta, inbox API, estado READY e conflito com vínculo existente. Repetir a operação reutiliza o vínculo local.

O contrato `/control/resources` do Broker acrescenta `connections`, com integrationId, inboxId, instanceId e name. A interface do JRC mostra somente caixas API pertencentes à conta autenticada. A adoção usa `POST /api/v1/accounts/:account_id/jrc_broker/adopt` com `{integrationId}`; IDs de conta, empresa ou inbox não são aceitos como autoridade no corpo.

No QR assíncrono, apenas o clique inicia a intenção. Quando o Broker retorna CONNECTION_PENDING, o painel recupera o resultado usando a mesma chave de idempotência, por até 60 segundos. Conexão, perda de permissão, troca de contexto ou saída interrompem a recuperação; QR não é persistido.

## Sequência obrigatória restante

1. A1/A2: contrato dedicado de acesso delegado ao editor, com autorização atual do usuário, empresa e inbox; integrar o editor ao JRC. A chave de QR não autoriza CRUD de automações. O embed de conexão existente também não constitui SSO do editor.
2. A3: propriedade exclusiva do motor por caixa, bloqueio de novos claims no motor anterior, coordenação de pendências e workers, transição e rollback auditados.
3. A4: handoff, supressão de respostas automáticas durante atendimento humano e retomada no ponto autorizado.
4. Completar a interface e contratos de cancelamento, reconexão, desvinculação e arquivamento, preservando histórico.
5. Conversão real de `jrc_flows` para o grafo do Broker, com relatório por nó e bloqueio de publicação quando houver semântica incompatível. A migração BROKER_FLOW_V1 existente não comprova essa conversão.

## Estrutura multiempresa confirmada no código

- `Account` é a fronteira de empresa do JRC; `AccountUser` concede associação e papel por conta. `InboxMember` concede participação na caixa.
- `JrcBrokerIntegration` vincula uma conta a uma organização do Broker, com unicidade por origem/organização. O contexto remoto precisa confirmar accountId, organizationId, origem HTTPS e revisão.
- `JrcBrokerInboxBinding` vincula uma inbox API dessa conta a integrationId/instanceId do Broker. Agentes são pessoas; instâncias são conexões WhatsApp e não substituem os agentes.
- Não foi encontrado relacionamento pai/filhas entre contas. Grupo JRC, GoPure, Construtora e Operadora devem manter contas/organizações separadas para isolamento. Usuários de gestão do grupo precisam de associações explícitas; o grupo não herda acesso às empresas por nome ou vínculo CRM.
- O enum base tem agent/administrator. Supervisor depende de custom_role no overlay Enterprise. A política Broker atual não concede gestão somente por esse rótulo: exige administrator. Membros da caixa consultam status; gerar QR/reconectar exige também concessão explícita can_pair e identidade aprovada. A concessão é revalidada depois da resposta remota; revogação durante o pedido impede revelar o código.
- A presença do módulo depende das features jrc_broker/jrc_flows da conta e habilitação da infraestrutura. Disponibilização comercial para todas as empresas requer um fluxo de provisionamento por empresa; não compartilhar a chave da conta 1 com outras contas.

## Validação local desta revisão

- Rails: 42 exemplos, zero falhas, incluindo adoção repetida, empresa distinta, usuário sem gestão, vínculo conflitante, conexão desabilitada e revogação de concessão durante o pareamento.
- Vue: 25 testes, incluindo adoção sem onboarding e QR assíncrono com intenção estável; lint sem erros (avisos preexistentes de chaves i18n dinâmicas).
- Broker: teste PostgreSQL de controle com 6 casos aprovado; typecheck aprovado. Suíte principal teve 1.230 aprovações e duas falhas; após corrigir o mock HTTP para o contrato novo, as duas suítes foram reexecutadas com 12 testes aprovados. A falha de espera do editor não se repetiu na reexecução isolada. Não foi uma única execução integral verde.
- LAB indicado pelo usuário: conta 1 em jrcconversas-lab.jrcws.cloud. A ferramenta de navegador falhou ao inicializar; não houve validação da sessão, pareamento ou mensagens reais.

## Aceite de publicação

Commits dos dois projetos, novos testes aprovados e isolamento de duas empresas. Homologação real em HTTPS:

adotar caixa → gerar QR → conectar WhatsApp → receber mensagem → executar fluxo → transferir ao atendente → responder → retomar bot.

Os testes locais não substituem essa jornada. Migrations, ENV, Compose e imagens permanecem sem definição final de publicação. Esta revisão não realiza deploy nem autoriza promoção de imagens.
