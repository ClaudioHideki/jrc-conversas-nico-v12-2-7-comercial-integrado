# NICO flutuante para o atendente

O ícone voltou a flutuar no canto direito. A faixa horizontal foi removida. O personagem usa a ilustração existente, com sombra, contorno e movimento discreto ao passar o mouse. A apresentação tem aparência tridimensional; a implementação usa a imagem atual e transições CSS, sem um modelo 3D articulado.

## Interação

- **NICO recolhido:** mascote de 56 a 72 pixels, nome e indicador de avisos pendentes. O conteúdo mantém um espaço lateral de 64 a 96 pixels para preservar campos e botões.
- **Novo aviso:** aparece um balão acima do personagem com o cliente e uma prévia. Ele se recolhe após 12 segundos; a contagem permanece. Enquanto o atendente lê com o mouse ou o foco dentro do balão, o fechamento automático é suspenso.
- **Tela estreita:** o personagem fica mais alto para manter distância dos controles de envio.
- **Recolher balão:** fecha a prévia e mantém o aviso não lido. O texto completo continua no painel.
- **Ver aviso:** abre as ações vinculadas àquele aviso e registra a leitura.
- **Clicar no personagem:** abre a conversa privada com o operador, incluindo os avisos, ações, voz, delegações e comprovantes existentes.
- **Painel aberto:** o espaço do mascote é devolvido ao painel. Ao recolher o painel, o ícone reaparece e recebe o foco do teclado.
- **Chamada ativa ou recebida:** o ícone vai para a parte superior do espaço lateral e o balão é recolhido, preservando os controles de chamada.

Nenhuma ação é executada por passar o mouse, abrir ou recolher o mascote. O reconhecimento por voz continua sendo iniciado pelo operador no painel. O comportamento respeita a preferência de redução de movimento.

## Escopo preservado

A alteração fica na interface: launcher, posicionamento no Dashboard, foco acessível do painel e textos. As 54 ferramentas, endpoints, permissões, confirmação das ações, atendimento delegado, fila de avisos e regra de saudações continuam usando a implementação existente. O cliente simulado permanece separado da conversa privada do atendente.

## Verificação

- Os 20 testes existentes de interface passaram: autenticação, sessões, voz, ações dos módulos e ações do navegador.
- ESLint dos três componentes alterados terminou sem erros (22 avisos de estilo/i18n).
- A interface compilou com sucesso e foi carregada pelo serviço web local.
- Em desktop (1920 × 950), o mascote de 72 pixels ficou separado do botão Enviar por 46 pixels na horizontal.
- Em 390 × 844, o mascote de 56 pixels ficou 50 pixels acima do botão Enviar, sem sobreposição ou rolagem horizontal da página. O botão e o balão foram inspecionados visualmente.
- Abertura do painel, foco dentro do painel e retorno do foco ao personagem foram conferidos na conversa #14, incluindo a apresentação em tela estreita.
- Um aviso fictício identificado como “Validação local” foi publicado pelo script `scripts/nico-avatar-ui-notice.rb`. Recolher o balão manteve o contador; “Ver aviso” abriu o aviso correspondente no painel e registrou a leitura. Nenhuma ação comercial foi executada nesse teste.
- A verificação somente de leitura `scripts/nico-notices-e2e.mjs verify` passou, preservando o contato, a atividade do CRM e os resultados anteriores.

Chamadas reais e uma nova gravação de voz não foram realizadas nesta validação de interface. O posicionamento durante chamadas foi conferido no código, e os testes existentes de voz passaram.

Para validar: abra a conversa #14, confira que o botão Enviar fica livre, clique no NICO, recolha o painel e acompanhe o aviso a partir de outro módulo. O balão é uma prévia temporária; o histórico completo fica no painel.
