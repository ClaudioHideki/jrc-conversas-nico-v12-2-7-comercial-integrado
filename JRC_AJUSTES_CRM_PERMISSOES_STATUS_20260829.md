# Ajustes JRC CRM — 29/08/2026

- Super Admin: os indicadores de funcionalidades da conta agora são clicáveis e ativam/desativam a feature diretamente.
- CRM: permanece visível no menu lateral mesmo desativado, em estado cinza/bloqueado.
- CRM: selo vermelho "Novo" no menu lateral.
- Caixa de Entrada > Canais configurados: adicionados CRM e WhatsApp Calling com status real Ativado/Desativado.
- CRM na lista de canais recebe selo "Novo".
- Permissão por agente: administrador da conta pode habilitar/desabilitar "Acesso ao JRC CRM" ao editar um agente.
- Segurança: endpoints do CRM exigem a feature da conta e permissão do agente; administradores da conta mantêm acesso quando a feature está ativa.
- Nova migration: account_users.crm_enabled.

Após atualizar um ambiente existente, execute as migrations (`rails db:migrate` / `rails db:prepare`).
