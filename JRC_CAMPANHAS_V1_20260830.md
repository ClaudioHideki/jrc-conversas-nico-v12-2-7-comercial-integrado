# JRC Campanhas V1 - 2026-08-30

Base: `jrcconversas-whatsapp-calling-v4-CRM-DEMO-20260829.zip`.

## Objetivo
Adicionar o primeiro esqueleto nativo do módulo JRC Campanhas sem substituir ou alterar os módulos validados de CRM e WhatsApp Calling.

## Implementado
- Feature flag `jrc_campaigns` (desabilitada por padrão, controlável por conta no Super Admin).
- Menu lateral `Campanhas` somente quando a feature estiver habilitada.
- Rota Vue `/app/accounts/:accountId/jrc-campanhas` protegida pela feature flag.
- Tela inicial com indicadores, listagem e criação de campanha.
- Disparadores V1: manual e agendado.
- Público V1: todos os contatos, etiqueta e estrutura preparada para inbox.
- Mensagem textual com estrutura preparada para variáveis como `{{nome}}`.
- Estados: draft, scheduled, running, paused, completed e canceled.
- API Rails account-scoped em `/api/v1/accounts/:account_id/jrc_campaigns/campaigns`.
- Ações de iniciar, pausar, retomar e cancelar.
- Estimativa de público baseada nos contatos reais da conta.
- Banco isolado na tabela `jrc_campaigns` ligado a account/inbox/user.

## Segurança de homologação
Nesta V1, iniciar uma campanha NÃO envia mensagens reais. Apenas altera o estado da campanha. O motor de envio, fila, rate limit e integração Evolution/WhatsApp serão adicionados na próxima etapa para evitar disparos acidentais.

## Próxima etapa sugerida
1. Seleção visual de inbox/instância Evolution.
2. Prévia real do público antes de iniciar.
3. Recipient snapshot e idempotência.
4. Job Sidekiq para envio em lotes.
5. Limites por minuto e janela de horário.
6. Status enviado/falhou e respostas.
7. Disparadores CRM/conversa/webhook.
8. Flow Builder.
