# Entrega GoPure — estado real de 08/09/2026

## Implementação

Sete perfis assistidos no painel da conversa, executados pelo runtime elizaOS existente: NICO, Comercial, CX, Suporte N1, Financeiro, Implantação e Supervisor. CRM autorizado, conhecimento aprovado e mensagens públicas da conversa continuam sendo as fontes locais. O Comercial pode preparar oportunidade; atividades e tarefas permitidas dependem de revisão humana.

Acrescentados serviço ERP com rotas fixas e sem operações de escrita, configuração administrativa por tenant, vínculo verificado por contato, fonte ERP explícita no contrato do modelo e revogação de resultados. O tenant GoPure 1 está na allowlist. Credenciais ERP ficam no serviço separado, não no elizaOS/modelo/navegador.

| Perfil | Contexto ERP implementado | Operações externas pendentes |
| --- | --- | --- |
| NICO | Cadastro e recorte de chamados | Envio automático de resposta |
| Comercial | Cadastro, além do CRM local | Proposta comercial e follow-up automático |
| CX | Cadastro e recorte de chamados | NPS persistido e churn medido |
| Suporte N1 | Cadastro e recorte de chamados | Abertura, atualização e diagnóstico remoto |
| Financeiro | Cadastro e cobranças do cliente | Segunda via, negociação, baixa e agenda de cobrança |
| Implantação | Cadastro e recorte de chamados | Provisionamento, portabilidade e checklist operacional persistido |
| Supervisor | Cadastro e recorte de chamados | Monitoramento global e orquestração automática |

Leitura ERP inicialmente restrita a administradores, com confirmação do contato autorizado. Não há associação automática de CNPJ escrito pelo cliente no chat. Modos fixture/live são separados e as fontes indicam data da consulta. A API BEMTEVI retornou repetição de código de cobrança: o adaptador não soma linhas, não multiplica dívida e pede conferência do valor consolidado.

## Códigos confirmados por consulta real

- Empresa operadora Help Desk **3: Operadora JRC**, sem CNPJ no retorno.
- Usuário Help Desk **4912** existe; a resposta não informa empresa vinculada.
- Cliente **CAVALARI PARTICIPAÇÕES EIRELI**, CNPJ **28.240.080/0001-71**: BEMTEVI **152**, Help Desk **536**.
- Os códigos 3/4912 são guardados como parâmetros operacionais para evolução do fluxo. O cliente da conversa usa seu vínculo 152/536. O contato sintético recebe apenas vínculo fictício 900001/900002.

## O que foi validado nesta máquina

- 20 testes Node passaram: contrato dos perfis/fonte ERP, autenticação do gateway, conta não autorizada, modo live bloqueado, CNPJ duplicado, cliente errado, ticket/cobrança de terceiro, exclusão de senhas e repetição de cobranças.
- Sete simulações com OpenAI passaram usando os prompts reais dos perfis, esquema JSON compartilhado com o runtime e contexto inteiramente fictício. Evidências: `validation/gopure-agent-simulations-provider.json` e `.md`.
- Consultas autenticadas reais de cadastro, usuário, chamados e formato de cobranças; nenhuma mensagem enviada e nenhuma escrita de negócio no ERP.
- Revisão de código corrigiu permissão de tenant e remoção imediata do resultado após alterar/revogar vínculo.

Esses testes não equivalem a uma homologação ponta a ponta no JRC/elizaOS. O Docker estava indisponível e o disco com pouco espaço. Migração nova, testes Rails novos, build TypeScript completo, build Vue e E2E precisam rodar no destino. O script `nico-package-verify.ps1` contém essas verificações, incluindo sete execuções reais na conversa sintética; utiliza a chave OpenAI e seu consumo normal.

## Transferência

O ZIP completo anterior é preservado como base e recebe a atualização em `Atualizacao`. `Aplicar-Atualizacao.ps1` confere hashes e aplica somente arquivos esperados; arquivos modificados fora do pacote bloqueiam a aplicação. As fontes novas serão compiladas pelo início no destino. Novos tokens OpenAI/ERP estão em envelope AES-256-GCM, com senha entregue fora do ZIP.

O banco exportado é de 07/09: não houve nova exportação de volumes após a falha do Docker. Imagens antigas incluídas não comprovam build da interface nova. O Broker permanece incluído; sua ponte de mensagens ao JRC não foi homologada. Canais WhatsApp/Instagram reais exigem configuração e testes próprios. Ana, campanhas autônomas e pós-venda completo não são substituídos por esses sete perfis.
