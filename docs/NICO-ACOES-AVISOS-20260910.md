# NICO: ações supervisionadas e avisos em todos os módulos

Atualização aplicada em 10/09/2026 ao ambiente local GoPure, no projeto `lab-gopure-nico-20260908/JRC-Conversas`.

## Como funciona

1. O operador delega a conversa ao NICO, com objetivo, duração e autorização explícita de criação automática do lead quando desejado.
2. O NICO conversa com o cliente, aproveita o histórico e identifica pedidos práticos. Coleta os dados essenciais e registra a necessidade para o operador.
3. Um aviso com o nome do cliente aparece na faixa inferior do sistema, inclusive quando o operador está em outro módulo. A interface consulta os avisos a cada quatro segundos.
4. **Ver aviso** abre a revisão das ações dessa conversa. Cada escrita mostra os dados e exige **Confirmar e executar**. Ações que dependem do navegador conservam a etapa de execução na aba do operador.
5. O resultado real atualiza o aviso. O planejador usa as etapas concluídas para preparar a próxima ação. Pedidos do cliente têm fila própria, preservada quando o operador faz outro pedido ao assistente.
6. Falhas de preparação mostram o motivo e permitem **Retomar pedido**. Um resultado desconhecido de execução não é repetido automaticamente: exige conferir o módulo.

O mascote é flutuante no canto direito, com espaço lateral para não ficar sobre o botão Enviar. Um balão breve apresenta os avisos; recolher o balão mantém o aviso pendente. O painel completo abre por iniciativa do operador. Os avisos permanecem no sistema até serem marcados como lidos; não são notificações do Windows e dependem de uma aba autenticada aberta. Veja [a atualização do mascote](NICO-MASCOTE-FLUTUANTE-20260910.md).

## Cobertura do catálogo

O catálogo contém **54 ferramentas**, entre consultas, navegação e ações. A disponibilidade é filtrada pelas permissões atuais do operador e pelos módulos habilitados.

| Área | Ações e consultas expostas |
| --- | --- |
| Cockpit e relatórios | Resumo operacional, contagens do escopo visível e navegação para indicadores |
| Conversas e caixa de entrada | Localizar e ler conversas, enviar resposta ou nota, alterar status, responsável, equipe, prioridade e etiquetas; delegar ou retomar o atendimento |
| Contatos | Buscar, cadastrar e atualizar nome, telefone e email |
| CRM | Leads, conversão, negócios, funis, atividades, agenda, produtos, propostas, itens, aprovação, envio e PDF |
| E-mails | Iniciar email em caixa configurada para contato com email cadastrado |
| Ligações e Calls | Discar por ramal, controlar chamada atual e iniciar WhatsApp Calling quando o canal permitir |
| Videoconferência | Abrir a sala configurada |
| Campanhas | Criar/editar rascunho, solicitar/aplicar aprovação, lançar, pausar, retomar, cancelar, consultar relatório e exportar CSV |
| Configurações | Consultar canais e perfil da conta, configurar fuso, alterar nome/idioma/email de suporte e ajustes selecionados da caixa; alterar disponibilidade do operador |
| Inteligência | Base aprovada de conhecimento e acesso aos módulos existentes de agentes, provedores e insights |

Isso não significa paridade com todos os botões do produto. Operações sem ferramenta específica usam a navegação/orientação para o módulo. Conexões, credenciais, permissões de microfone e aprovações comerciais continuam seguindo os fluxos existentes. Nenhuma consulta a ERP Bemtivi ou helpdesk foi adicionada.

## Continuidade e controle

- Saudações como “Olá”, “Oi” e “Bom dia” são preservadas na primeira resposta; nas seguintes, o servidor remove a saudação inicial repetida e o modelo recebe orientação para continuar o diálogo.
- O planejador recebe contato, conversa e leads/negócios vinculados, respeitando o escopo do operador. Não depende de pedir IDs ao humano quando esses dados já estão disponíveis.
- Campos opcionais nulos vindos do modelo são omitidos; campos obrigatórios e desconhecidos continuam sendo validados. Parâmetros incompletos podem ser corrigidos pelo planejador dentro de um limite de quatro consultas/tentativas.
- Pedidos de cliente não dão autorização administrativa. Escritas são revisadas; acesso à conversa, ao contato e aos vínculos é revalidado antes da execução.
- Avisos são vinculados à conta e ao operador responsável pela delegação, com revalidação de acesso. Encaminhamento ao humano, falha de atendimento e expiração da delegação também geram avisos.
- O resumo livre do modelo pode ainda usar frases imprecisas sobre o estado; os comprovantes de cada ação mostram o resultado real. A conclusão do trabalho não envia automaticamente uma confirmação adicional ao cliente.

## Validação realizada

- **33 exemplos Rails passaram**, cobrindo os avisos, isolamento por operador, permissões atuais, preservação de pedidos, retomada após falha, prevenção de repetição, parâmetros opcionais, atividade vinculada e regressões operacionais.
- **20 testes da interface** e **16 testes do runtime** passaram. ESLint dos componentes alterados sem erros; interface compilada e aplicada localmente.
- Teste com provedor real: mensagem #70 da cliente fictícia Marina pediu atualização de email e reunião para 11/09/2026 às 15h de Brasília. O aviso #1 apareceu fora da conversa, no CRM.
- Comando #40, confirmado pela interface: contato #53 atualizado para `marina.nico.local@example.test`.
- A primeira tentativa de agendamento revelou um parâmetro opcional nulo. O erro foi corrigido; **Retomar pedido** foi validado pela interface. A consulta de vínculos foi incorporada ao contexto para evitar uma pergunta desnecessária ao operador.
- Comando #43, confirmado pela interface: atividade #9 criada no lead #16 da Marina. Horário persistido `2026-09-11T18:00:00Z`, equivalente a `2026-09-11T15:00:00-03:00`.
- Fuso da conta local configurado pela ferramenta administrativa do NICO para `America/Sao_Paulo`; a lista de atividades exibe **11/09/2026 15:00**.
- Resposta #71: “Marina, vou solicitar ao responsável...”, sem nova saudação nem alegação de que a ação já havia sido concluída antes da aprovação.
- Evidência estruturada em [validation/nico-notices-e2e.json](validation/nico-notices-e2e.json). O histórico de falhas anteriores permanece para auditoria.

Chamadas, envios reais de email/WhatsApp, disparos de campanha e entrada em videoconferência não foram realizados nesta homologação. Esses fluxos exigem os respectivos canais configurados. A caixa fictícia utiliza a API pública local sem número real ou webhook externo.

## Acesso para continuar

- Cliente: http://localhost:3107/nico-cliente-teste/
- Operador: http://localhost:3107/app/accounts/1/conversations/14
- Atividade no CRM: http://localhost:3107/app/accounts/1/crm/activities

Digite como cliente na página do simulador. Escrever na caixa de resposta do operador é uma intervenção humana e pausa o NICO. A delegação tem duração limitada; quando expirar, delegue novamente pelo painel.

## Aplicação em outra instalação

Esta mudança exige a migration `20260910130000_create_nico_notices.rb`, reinício de web/worker, build do runtime e build da interface. Servidor e runtime devem ser atualizados juntos, pois o contrato da resposta ao cliente ganhou `operator_request`.

O Docker local usa `DB_POOL_SIZE=6`, mantendo dois jobs concorrentes, para acomodar também as tarefas auxiliares. O valor padrão de instalações que não definirem essa variável foi preservado. Os assets servidos são estáticos: abas abertas antes da atualização precisam ser recarregadas.
