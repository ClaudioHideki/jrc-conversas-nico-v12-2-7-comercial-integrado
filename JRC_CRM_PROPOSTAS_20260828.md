# JRC CRM — Negócios e Propostas — 28/08/2026

## O que foi incluído

- Negócio criado pela conversa reaproveita cliente, origem, conversa e responsável.
- Cadastro rápido de cliente no formulário de novo negócio.
- Origem padronizada por combo list.
- Produtos, quantidade, preço, desconto e total no negócio.
- Edição do negócio pelo painel lateral: cliente, responsável, etapa, origem, valor e produtos.
- Proposta criada a partir do negócio copia produtos e descontos.
- Campos comerciais da proposta: título, descrição da solução, implantação, mensalidade, validade, vigência, observações comerciais e próximos passos.
- Página pública responsiva da proposta com identidade JRC (sem logo do cliente).
- PDF A4 gerado pelo backend, com logo JRC, produtos, descontos e condições comerciais.
- Visualização e download do PDF.
- Envio da proposta por WhatsApp ou e-mail usando uma conversa existente do cliente.
- O envio inclui link público + PDF anexado e fica registrado como mensagem na conversa.
- Evento de envio e visualização registrado na timeline do CRM.
- Botões rápidos na lista de propostas: editar, visualizar, PDF, WhatsApp e e-mail.

## Regra de entrega

1. Usa primeiro a conversa já vinculada ao negócio quando o canal coincide.
2. Se o usuário escolher WhatsApp ou e-mail e a conversa vinculada for de outro canal, procura outra conversa já existente do mesmo contato.
3. Não cria uma nova conversa/inbox silenciosamente. Se não houver canal compatível, retorna erro para o usuário.

## Banco de dados

Nova migration:

`20260828000020_add_commercial_fields_to_jrc_crm_proposals.rb`

Depois de atualizar o projeto, executar:

```bash
bundle exec rails db:migrate
```

Em Docker Compose local:

```bash
docker compose -p jrc-crm-validacao exec rails bundle exec rails db:migrate
```

## Observação

O PDF é gerado sem dependência externa de wkhtmltopdf/Chromium/Prawn. O logo é lido de `public/brand-assets/logo-jrc.png` e convertido para o PDF usando a infraestrutura de imagem já existente no projeto.
