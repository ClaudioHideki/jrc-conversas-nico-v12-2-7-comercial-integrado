# JRC V12-2-4 - CRM, permissões e Cockpit

Atualização baseada na V12-2-3.

- JRC CRM passa a ser liberado para administradores e agentes quando a feature `jrc_crm` da conta estiver ativa.
- Removida a dependência do `crm_enabled` individual para acesso ao CRM.
- Cockpit passa a receber `emails_unread` do backend, com contagem por caixas visíveis e fallback direto no banco.
- Agentes não recebem custo/margem no endpoint de produtos.
- Agentes não veem Margem média, Margem, Custo nem ações de alteração de produto.
- Cadastro, edição, exclusão, ativação/desativação e importação continuam protegidos para administrador no backend.
