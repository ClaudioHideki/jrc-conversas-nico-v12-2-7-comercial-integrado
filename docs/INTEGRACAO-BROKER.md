# JRC Conversas e JRC WhatsApp Broker — avaliação local

Avaliação de código em 07/09/2026. Foram inspecionadas as pastas `JRC-WhatsApp-Broker` (Incremento 1) e `JRC-WhatsApp-Broker-web-console` (Incremento 2). Esta é uma avaliação de viabilidade e contratos; não houve pareamento de número nem teste de mensagens reais.

## Conclusão

É viável conectar os produtos por um adaptador de integração. A conexão de atendimento ainda não está implementada: o broker atual gerencia organizações, autenticação, chaves e o ciclo de vida de instâncias; faltam os contratos operacionais de mensagens e eventos.

| Capacidade | Situação verificada |
|---|---|
| Login, organizações, RBAC, API keys | Existem no broker; a Console acrescenta a interface de administração |
| Criar/conectar/desconectar/consultar instância | Rotas `/v1/instances` e operações de conexão/status existentes |
| Enviar mensagem por API pública JRC | Ausente no OpenAPI e no registro de rotas atual |
| Receber mensagem e entregar evento ao JRC Conversas | Webhooks completos e workers estão fora do incremento atual |
| Meta Cloud API no broker | Adaptador ainda descrito como esqueleto; não homologado |
| Entrada de atendimento no JRC Conversas | Canal API e APIs de contatos/conversas/mensagens existentes |
| Saída do JRC Conversas | `WebhookListener#message_created` e webhook do canal API existentes |
| NICO no atendimento | Analisa o contexto já registrado no JRC; não conecta o número e não envia respostas automaticamente |

## Arquitetura recomendada

```text
WhatsApp <-> provider privado do broker <-> API/eventos JRC Broker
                                             <-> adaptador JRC
                                             <-> caixa de entrada API do JRC Conversas
                                                     -> NICO assistido -> atendente
```

O adaptador deve mapear organização/instância do broker para conta/caixa de entrada do JRC. O identificador externo do contato e da mensagem deve ser persistido para evitar duplicação e ciclos de reenvio. As credenciais administrativas da Evolution permanecem no broker; o adaptador usa uma chave JRC com escopo mínimo.

## Implementação necessária, em ordem

1. Definir e implementar no broker o contrato canônico de envio de texto, recebimento e atualização de status. Mídia, templates e demais tipos precisam de capacidades explícitas por provider.
2. Implementar autenticação e assinatura dos eventos, filas, tentativas limitadas, deduplicação, tratamento de falhas e rastreabilidade por organização.
3. Implementar o adaptador: entrada cria/localiza contato e conversa; saída consome somente mensagens públicas de saída autorizadas, ignorando notas internas e mensagens recebidas.
4. Mapear estados de envio/entrega/leitura sem registrar como entregue uma mensagem apenas aceita pelo provider. Preservar idempotência após falhas e reinícios.
5. Configurar uma caixa API de homologação e uma instância de teste. Validar texto em ambos os sentidos, eventos repetidos, isolamento entre duas contas, indisponibilidade e retomada. Depois homologar mídias e regras do canal.
6. Disponibilizar configuração administrativa e monitoramento da conexão; só então habilitar um número real autorizado.

O ambiente NICO atual usa rede Docker interna. O adaptador exigirá conectividade controlada entre os serviços e endereços alcançáveis pelos containers; `localhost` dentro de um container não aponta para o outro produto.

## Evidências no código

- Broker Console: `README.md`, `docs/api/openapi.json`, `apps/api/src/app.ts`, `packages/providers/src/contracts/provider.ts` e `docs/architecture/system-boundaries.md`.
- JRC Conversas: `app/models/channel/api.rb`, `app/listeners/webhook_listener.rb` e controllers de contatos/conversas/mensagens da API.
- O OpenAPI atual lista autenticação, API keys, provider accounts e instâncias; não lista endpoints de mensagens.

Não basta informar uma chave OpenAI para esta integração. A chave habilita o provedor de IA após configuração do runtime; transporte WhatsApp, broker, credenciais do canal e o adaptador são componentes distintos. Instagram também não é coberto pelo broker WhatsApp atual.
