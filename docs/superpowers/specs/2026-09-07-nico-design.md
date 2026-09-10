# NICO no JRC Conversas V11

## Objetivo autorizado

Implementar a arquitetura recomendada nas validações de 7 de setembro de 2026, após o pedido do usuário para estruturar o plano e executá-lo. Preservar Rails/Vue, CRM, campanhas, telefonia e identidade JRC; integrar elizaOS internamente. Não publicar, disparar mensagens para clientes nem usar credenciais do ZIP.

## Decisões

Rails permanece autoridade de conta, usuário e recurso. Vue usa a sessão existente. O runtime TypeScript recebe somente contexto previamente autorizado e credencial técnica interna; não recebe credenciais administrativas de Chatwoot/Hodu. Modelos e plugins serão fixados após prova da versão publicada.

NICO começa assistido: leitura de conversa, dados CRM visíveis ao operador, conhecimento aprovado, resumo e sugestão com evidências. A interface mostra estado real da execução. Ações de escrita relevantes exigem proposta persistida, aprovação humana e execução idempotente. Campanhas seguem revisão separada de segurança e aprovação antes de envio. Telefonia real depende do contrato externo já identificado para CDR; nenhum endpoint de click-to-call será inventado.

## Componentes

- Runtime em `services/nico-runtime`, com health, autenticação interna, saída validada e integração elizaOS testável.
- Rails `JrcNico`: execuções persistidas, contexto autorizado, cliente do runtime e jobs Sidekiq.
- Painel existente com contexto de conversa, cancelamento/troca de conta seguros e evidências.
- Campanhas: policy, mesma conta em inbox, aprovação versionada, blacklist no envio e controle de concorrência.
- Homologação isolada em Docker, sem depender do .env original; dados de teste e rede locais.

## Contrato interno inicial

`POST /v1/analyze`, header `Authorization: Bearer <service-token>`, recebe JSON `{request_id, account_id, agent_key, message, context: {conversation, crm, knowledge}, history}`. Contexto inclui apenas dados autorizados e referências de evidência. Resposta `{summary, suggested_reply, evidence: [{source, reference}], warnings, usage: {input_tokens, output_tokens, total_tokens}, model}`. Falha retorna código explícito, nunca sucesso sintético. A credencial de modelo pertence à implantação de runtime de homologação; tenants com credenciais próprias serão mapeados no servidor por account_id, sem aceitar chaves do navegador.

## Invariantes

- Isolamento por conta e visibilidade do operador, inclusive em consulta e histórico.
- Feature NICO habilitada por conta, com falha fechada quando runtime/modelo ausente.
- Sem envio público automático no copiloto inicial.
- Segredos não entram em Git, logs, respostas ou imagens.
- Nenhum status de agente, custo ou integração é declarado confirmado sem execução.
- Testes com dois tenants, erros externos, retry e concorrência.

## Aceite

Ambiente isolado sobe com migrations; testes relevantes Rails e Vue passam; runtime usa elizaOS real com versões fixadas; contratos passam com provedor de teste controlado; resultado mostra fontes; usuário sem acesso é bloqueado. A homologação externa requer provedor e conta reais e será registrada separadamente, sem confundir mock com operação externa.

## Alternativas consideradas

Reescrever em Fastify/React duplicaria o produto e suas permissões. Manter apenas chamada direta ao modelo reduziria dependências, mas não realizaria a adoção elizaOS solicitada. Integração interna preserva o produto existente e torna o motor substituível.
