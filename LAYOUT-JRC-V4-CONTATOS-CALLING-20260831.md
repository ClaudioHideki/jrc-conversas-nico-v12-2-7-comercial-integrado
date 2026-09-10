# JRC Layout V4 - Contatos + WhatsApp Calling

Versao de teste criada a partir da V3 validada localmente.

## Contatos
- Nova apresentacao "Central de Relacionamentos".
- Cards de indicadores no topo.
- Lista em formato de tabela comercial.
- Acoes rapidas WhatsApp, ligar e agenda.
- Painel lateral com dados do contato, responsavel, negocio/CRM e historico visual.
- Mantidas busca, paginacao e abertura do perfil do contato.

## WhatsApp Calling
- Layout reorganizado para aproximar a experiencia da referencia enviada.
- Contatos a esquerda, workspace/discador no centro e chamada/CRM/IA a direita.
- Cartao de chamada com status, waveform visual e controles principais.
- Bloco de informacoes comerciais/CRM.
- Bloco de IA de sentimento preparado visualmente para Voice Quality.
- Historico de chamadas mantido.
- Fluxos reais existentes de permissao, ligar, mudo e encerrar foram preservados.

## Observacao sobre IA ao vivo
O bloco de IA nesta V4 e uma camada de interface para teste. A captura/transcricao em streaming do audio do WhatsApp Calling ainda nao foi ligada ao JrcVoiceQuality. O processamento existente de Voice Quality continua preservado.

## Portas locais V4
- Rails: 3006
- Vite: 3042
- PostgreSQL: 55446
- Redis: 56394
- Mailhog SMTP/UI: 1031/8032
