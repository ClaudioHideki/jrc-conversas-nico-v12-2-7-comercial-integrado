Atualização posterior: consulte [ENTREGA-GOPURE-20260908.md](ENTREGA-GOPURE-20260908.md) para a implementação de leitura ERP, configuração e testes. As seções abaixo registram também a análise anterior à implementação.

# BEMTEVI e Ksys Help Desk no JRC Conversas

Análise de 08/09/2026. Fontes: PDF `Documentação API BEMTEVI 2.0.pdf`, 33 páginas; OpenAPI 3.0.3 do Ksys HelpDesk, versão 1.4.0, obtida de https://api.ksys.net.br/php-helpdesk/openapi.yaml. Confrontado com os DOCX GoPure/NICO e a matriz de agentes de 08/09. Exemplos e tokens dos documentos não foram utilizados para acessar dados.

## Parecer

As duas APIs permitem conectar consultas financeiras, cadastro de clientes e chamados aos agentes dentro das conversas. Não comprovam capacidade de configurar PABX, executar portabilidade, negociar dívidas ou realizar todo o fluxo automático do projeto. A documentação é suficiente para desenhar os adaptadores; a homologação real ainda exige credenciais próprias, vínculos de clientes e respostas reais do BEMTEVI.

## Cobertura por agente

| Agente | Integração proposta | O que continua faltando |
|---|---|---|
| NICO/Copiloto | Resumo da conversa com fontes CRM, cobranças e chamados do cliente vinculado | Contexto ERP autorizado, validade das fontes e testes reais |
| Comercial | Consultar cliente/planos BEMTEVI; qualificar no JRC; oportunidade e follow-up no CRM JRC | Aprovação para cadastro externo; regra de sincronização para evitar duplicidade |
| CX | Combinar pendências de chamados e cobranças com o histórico da conversa | NPS não aparece nas APIs; risco deve ser indicador explicável, sem tratar hipótese como churn confirmado |
| Suporte N1 | Consultar tickets Ksys, usar conhecimento aprovado, simular e propor abertura de chamado | Configuração de tipo/item/serviço e vínculo de solicitante; API não documenta atualização, comentário, anexo ou fechamento de ticket |
| Financeiro | Consultar `/cobrancas`, solicitar `/cobranca/segundaVia` após revisão | Contrato de resposta, situação de pagamento, efeitos da segunda via; D-3/D0/D+7 precisa de agenda própria, reconsulta e controle de envio; negociação não documentada |
| Implantação | Consultar planos/cliente e abrir chamado classificado de implantação | Checklist persistente, dependências e responsáveis; sem API documentada de ramais, números, portabilidade ou ativação do PABX |
| Supervisor | Monitorar execuções locais, propostas, falhas e protocolos vinculados | Supervisão global, tomada humana e reconciliação de operações externas; listagem de tickets não documenta campo de vencimento SLA |

G01 (orquestração), G05 (campanhas), G06 (pedidos), G11 (conhecimento) e G12 (governança) do documento original continuam sendo componentes próprios. Conectar os ERPs não os implementa automaticamente.

## Contratos verificados

### BEMTEVI

Base: `https://api-bemtevi.ksys.net.br`. Autenticação por header `token`, fixo e fornecido pela Ksys (página 6).

| Operação documentada | Uso no JRC | Página |
|---|---|---|
| `GET /cliente` | Identificar cadastro externo; filtros incluem codcliente e cpfcnpj | 9–10 |
| `POST /cliente` | Criar cliente após revisão e deduplicação | 10 |
| `GET /cliente/planos` | Consultar plano/contrato associado | 16 |
| `POST/PUT /cliente/planos` | Alterações comerciais; não habilitar automaticamente no MVP | 16–18 |
| `GET /cobrancas` | Consultar cobranças do cliente explicitamente vinculado | 20 |
| `POST /cobranca/segundaVia` | Solicitar segunda via com codcliente e codcobranca | 29–30 |
| `GET/POST /suportes` | Alternativa de chamados BEMTEVI; não abrir simultaneamente nos dois sistemas | 30–31 |
| `GET /planos` | Catálogo de planos para consulta Comercial | 25 |

O PDF não define schemas completos das respostas, paginação, rate limit, idempotência ou webhooks. Não assumir que segunda via devolve URL, PDF, PIX ou linha digitável; validar a resposta e se há envio/efeito de emissão. Não assumir que alteração de preço em plano equivale a renegociação de uma cobrança.

Inconsistências que exigem confirmação: títulos `ENDPOINT` divergem das URLs em e-mail/endereço/redes sociais/suportes; `/cobrancas` lista `codcliente`, mas o exemplo usa `cpfcnpj`; vários GET mostram corpo JSON. Validar filtros em homologação, sem fallback para listagem de toda a base. A afirmação genérica de quatro verbos HTTP na apresentação não substitui o contrato de cada operação.

### Ksys Help Desk

Base: `https://api.ksys.net.br/php-helpdesk`. Dois headers obrigatórios: `Authorization: Bearer ...` e `Authorization-Bemtevi: Bearer ...`. O segundo seleciona a base da empresa; não é um parâmetro que o modelo ou visitante deve escolher.

| Operação | Uso |
|---|---|
| `GET /clientes.php` | Sincronização administrativa paginada para vincular empresas; não enviar listagem inteira ao modelo |
| `GET /usuario.php` | Resolver solicitante dentro da empresa |
| `GET /tickets.php?cod_empresa=...` | Chamados filtrados pela empresa vinculada; revalidar COD_EMPRESA em cada resultado |
| `POST /criar_solicitacao.php` com `simular: true` | Validar classificação, distribuição, prioridade e prazo sem gravar nem consumir protocolo |
| Mesma rota com execução aprovada | Criar chamado, guardar COD_SOLICITACAO e resultado do ERP |
| `POST /criar_usuario.php` | Cadastro externo de empresa/usuário; fora da abertura automática inicial |

Limite: 60 requisições/minuto/IP, `429` e `Retry-After`. Paginação padrão 50, máximo 200. Coordenar limite entre contas que compartilham IP, com cache isolado por conta e limites de páginas.

Abertura exige assunto (máximo 150), descrição, tipo/item/serviço coerentes, empresa e usuário vinculado. Preferir códigos previamente verificados em vez de busca por nome. A documentação não oferece endpoints de catálogo de tipo/item/serviço: obter tabela válida da base com administrador. Usar texto puro, escapando conteúdo do atendimento, pois a API informa que HTML enviado é armazenado como está.

Status inicial é sempre `COD_STATUS=1` (Nova). **No BEMTEVI, código 1 significa Cancelado e 2 significa Aberto. Não compartilhar o mapa numérico de status entre os dois adaptadores.** Normalizar estados por sistema e preservar valor original.

SLA e distribuição são calculados pelo Help Desk; não inventar prazo no modelo. A resposta da criação inclui grupo e vencimento. Datas no fuso America/Sao_Paulo. A listagem de Ticket não inclui vencimento no schema: guardar o retornado na criação e confirmar endpoint/campo adicional para monitorar SLA atualizado de tickets preexistentes.

Limites declarados: não envia e-mails de abertura; usa calendário padrão da base, sem calendário próprio de contratos. Não há garantia documentada de idempotência; `request_id` de erro é rastreabilidade, não chave de deduplicação de escrita.

## Arquitetura de implementação

```text
WhatsApp/Instagram → caixa do JRC Conversas → contato e conta autorizados
  → vínculo confirmado com cliente BEMTEVI e empresa/usuário Help Desk
  → Rails consulta adaptador específico e seleciona campos permitidos
  → elizaOS recebe contexto limitado, com fonte e horário da consulta
  → agente apresenta análise e proposta de ação
  → revisão humana → executor Rails → protocolo/resultado do ERP
  → histórico da conversa, auditoria e acompanhamento
```

As APIs ERP não substituem os canais WhatsApp/Instagram e não devem ser chamadas diretamente pelo navegador ou pelo modelo. A chave OpenAI gera análises; não autentica BEMTEVI ou Help Desk.

Criar vínculos `account_id + contact_id + integration_id → external_customer_id/external_company_id/external_user_id`, confirmados por administrador e únicos por integração. Número de WhatsApp, nome ou CPF digitado na mensagem não bastam para autorizar acesso financeiro. Uma empresa pode ter vários contatos; acesso a faturas exige autorização do solicitante, além do vínculo empresarial.

Credenciais em cofre/ambiente por conta. Backend define host e caminhos permitidos. Contexto usa somente campos necessários; excluir senhas, tokens, credenciais de plano, dados bancários desnecessários e listagens de terceiros. A busca de conhecimento não deve armazenar indiscriminadamente respostas ERP. Registrar referência, data, conta e validade da consulta; revalidar antes de aprovar.

Ferramentas recomendadas: `bemtevi.customer.read`, `bemtevi.plans.read`, `bemtevi.charges.read`, `bemtevi.second_copy.request`; `helpdesk.tickets.read`, `helpdesk.ticket.preview`, `helpdesk.ticket.create`. Permissões por perfil e usuário, sem HTTP genérico. Consultas não exigem nova aprovação a cada uso quando autorizadas; segunda via e criação começam com revisão humana.

Estados de efeito externo: `pending → approved → executing → succeeded / failed / unknown`. Uma queda após POST pode ter criado o chamado: marcar `unknown`, reconciliar e não repetir automaticamente. Guardar protocolo confirmado e chave local de proposta; simulação não é confirmação de criação. Não garantir “exatamente uma vez” no ERP sem suporte dele.

## Sequência recomendada e critérios de aceite

1. Concluir catálogo e seleção assistida dos agentes no JRC, sem regressão do NICO.
2. Configurar credenciais de homologação e vínculos de um cliente fictício por conta. Verificar que conta A não consulta cliente da conta B e que identidade não confirmada não libera dados.
3. Implementar adaptadores de leitura com respostas reais sanitizadas. Cobrir timeout, filtro ignorado, resposta malformada, paginação, 401/403/429 e revogação de vínculo.
4. Suporte: simular abertura, mostrar tipo/item/serviço, prioridade/grupo/SLA ao atendente; executar uma criação aprovada em base de testes; comprovar protocolo e ausência de duplicação por duplo clique. Timeout após escrita não pode produzir retry cego.
5. Financeiro: consultar situação e segunda via; comprovar que cobrança pertence ao cliente, link/arquivo é validado e resultado não é inventado. Confirmar efeitos externos da rota antes de habilitar.
6. Acrescentar acompanhamento e Supervisor. Para D-3/D0/D+7, usar data/fuso definidos, reconsultar pagamento imediatamente antes do envio, deduplicar por cobrança/marco/canal e respeitar pausa humana e regras do canal. Ausência de status financeiro confiável bloqueia cobrança automática.
7. Somente após validar a API de telefonia, implementar provisionamento/portabilidade. Chamados de implantação podem operar antes disso, sem afirmar que executam a configuração.

## Dados necessários para homologação real

- Tokens próprios de teste de BEMTEVI e Help Desk no ambiente/cofre, nunca nesta documentação.
- Confirmação de base de homologação e um cliente/empresa/usuário fictícios vinculados.
- Códigos válidos de tipo/item/serviço/origem para suporte, PABX e implantação.
- Exemplos sanitizados de retorno de cobranças e segunda via; regras de pagamento/estorno/cancelamento e efeitos da emissão.
- API específica de telefonia, se desejado provisionamento; tabela de status Help Desk e confirmação de consulta de SLA atualizado.

Atualização de 08/09/2026: foram realizadas consultas autenticadas de leitura, com credenciais mantidas no arquivo local ignorado pelo Git. Não foram emitidas segundas vias nem abertos chamados externos. A implementação dos adaptadores ERP dentro das conversas e a homologação ponta a ponta permanecem pendentes.

## Validação do CNPJ autorizado

O CNPJ **28.240.080/0001-71** retornou **CAVALARI PARTICIPAÇÕES EIRELI** em ambos os sistemas:

| Sistema | Identificador confirmado | Consulta |
| --- | --- | --- |
| BEMTEVI | `cod_cliente = 152` | GET `/cliente`, corpo JSON com `cpfcnpj` |
| Help Desk | `COD_EMPRESA = 536` | GET `/clientes.php`, seis páginas de até 200 registros |

Todas as consultas retornaram HTTP 200. O Help Desk apresentou uma única correspondência exata nas seis páginas consultadas. Na validação Node, o BEMTEVI retornou `data` como lista de um cliente; o adaptador aceita objeto ou lista e exige correspondência única. O identificador retornado é `cod_cliente`; não assumir o nome `codcliente` no parser da resposta. O cadastro inclui campos de autenticação da central do assinante: usar uma lista explícita de campos permitidos antes de qualquer persistência ou envio ao modelo.

Evidência sanitizada: [erp-customer-20260908.json](validation/erp-customer-20260908.json). Foram registrados somente os identificadores e o nome do CNPJ solicitado, além de metadados técnicos. Os cadastros dos demais clientes não foram gravados. Esses resultados confirmam autenticação e resolução cadastral; ainda não comprovam consulta de cobranças, chamados ou autorização de um contato da conversa. Nenhum vínculo com a conversa sintética 1 foi criado automaticamente.

## Decisão informada pelo usuário
Não existe base de homologação neste momento. O identificador de busca será o CNPJ. Normalizar sem perder zeros e sem converter para número; comparar exatamente com o cadastro retornado, exigindo correspondência única. BEMTEVI documenta filtro cpfcnpj em /cliente. Help Desk não documenta filtro CNPJ em /clientes.php: resolver em sincronização administrativa paginada e armazenar COD_EMPRESA. Não presumir que codcliente e COD_EMPRESA sejam iguais. Ambiguidade, ausência ou mais de um cadastro exige revisão de vínculo. O CNPJ identifica empresa; não autoriza sozinho acesso financeiro do contato. Operações ERP permanecerão desativadas até configurar vínculo, credencial própria e validação controlada.

Atenção ao solicitante: /usuario.php permite cod_usuario e paginação, mas não documenta filtro por empresa nem retorna COD_EMPRESA no schema Usuario. Portanto, sua resposta isolada não comprova vínculo empresarial. O vínculo deve ser configurado/confirmado administrativamente e validado pelo dry-run da abertura, que checa empresa e usuário. Não oferecer uma listagem global de usuários ao atendente ou ao modelo.

