# JRC Conversas — Layout V5 (31/08/2026)

Base: V4 Contatos + WhatsApp Calling.

## Alterações desta versão

- Agenda CRM: botões de mês anterior/próximo funcionais no mini calendário e no calendário principal; botão Hoje funcional; grade semanal recalculada conforme o mês selecionado.
- Navegação CRM: cor ativa por módulo (Visão Geral azul, Indicadores ciano, Leads/Funil/Agenda roxo, Negócios/Atividades laranja, Produtos verde e Propostas rosa) e fundo azul-cinza com degradês suaves.
- Visão Geral: cards comerciais, pipeline, prioridades e atalhos com hierarquia visual mais forte.
- Indicadores: gráfico de origem dos leads, ranking de receita por vendedor e exportação CSV funcional.
- Leads: cards de resumo, alternância Lista/Kanban funcional e Kanban por status.
- Atividades: filtros coloridos, status `scheduled` exibido como `Agendada`, prioridade visual, ações rápidas, próxima atividade, resumo e alerta de atrasos.
- Minha Carteira: mais indicadores, valor da carteira, pendências, atalhos coloridos e prioridades recomendadas.
- WhatsApp Calling + Conversas: área central unificada com alternância Conversa / Teclado-Calling; ao selecionar um contato, as conversas reais do contato são carregadas via API; é possível abrir a conversa e voltar ao discador sem sair do contexto de atendimento.
- WhatsApp Calling: controles, permissões, histórico, CRM e painel de IA preservados.
- Branding/logotipo JRC preservado.

## Observação sobre IA de voz

O painel de IA continua preparado para integração com Voice Quality. Esta versão não afirma captura de áudio em tempo real: a ponte de áudio WebRTC para análise contínua deve ser validada separadamente.

## Portas locais V5

- Rails: 3007
- Vite: 3043
- PostgreSQL: 55447
- Redis: 56395
- Mailhog SMTP: 1032
- Mailhog UI: 8033
