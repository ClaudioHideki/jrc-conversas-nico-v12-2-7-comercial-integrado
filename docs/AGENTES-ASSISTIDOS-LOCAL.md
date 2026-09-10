Atualização: a implementação ERP posterior e os limites atuais estão em [ENTREGA-GOPURE-20260908.md](ENTREGA-GOPURE-20260908.md). Este documento registra a etapa inicial assistida.

# Agentes assistidos no JRC Conversas

Implementação de 08/09/2026, continuando o piloto NICO. Esta entrega acrescenta especialização assistida; não conclui o MVP completo dos documentos GoPure.

## O que foi acrescentado

- Sete perfis fixos no runtime elizaOS: NICO, Comercial, CX, Suporte N1, Financeiro, Implantação e Supervisor.
- Seleção de perfil no painel da conversa. O backend valida habilitação por conta (`nico_enabled` e, opcionalmente, `nico_agent_keys`), registra a chave na execução e contabiliza consumo por agente.
- Fingerprint distingue pedidos iguais enviados a especialistas diferentes. Requisições repetidas ao mesmo agente são deduplicadas; continua existindo apenas uma execução ativa por conta.
- Central de Agentes apresenta o catálogo e estados reais de execuções próprias e autorizadas. Os cartões não chamam mais o copiloto genérico legado.
- Ações locais: acompanhamento, tarefa interna e, para Comercial, oportunidade vinculada ao lead/conversa. Todas exigem formulário, revisão e aprovação. Repetir a aprovação não repete o efeito.
- Oportunidade começa sem valor estimado (zero, com marcação de valor pendente) no primeiro estágio não terminal do primeiro funil ativo. O prazo informado vira previsão de fechamento e prazo da tarefa vinculada. Não gera proposta comercial nem envio ao cliente.

## Usabilidade

1. Abra uma conversa visível na sua conta e clique em **Copiloto JRC**.
2. No campo **Agente especialista**, escolha o perfil e confira as limitações exibidas.
3. Informe a pergunta e clique em **Analisar com o agente selecionado**.
4. Confira o nome do agente responsável, resumo, sugestão e referências. A sugestão não é enviada automaticamente.
5. Se a análise citar um lead autorizado, abra **Preparar ação no CRM**, escolha a operação permitida, preencha título/prazo e prepare a revisão.
6. Revise a proposta, marque a autorização e execute. Para alterar estágio/valor de oportunidade depois da criação, utilize o CRM.

Cancelamento interrompe a apresentação do resultado e impede publicação tardia da análise cancelada; uma chamada ao provedor já iniciada ainda pode ser cobrada. Não existe resposta automática ao canal nesta etapa.

## Como o elizaOS participa

O serviço utiliza um `AgentRuntime` elizaOS com despachante de análise e perfis de sistema selecionados por chave validada. Não são sete processos independentes nem uma rede de agentes delegando tarefas entre si. O modelo recebe somente contexto autorizado do Rails e retorna análise estruturada; efeitos de negócio permanecem no executor Rails após aprovação humana. Não foi criado acesso HTTP genérico ou ferramenta de execução arbitrária para o modelo.

## Limites atuais

| Perfil | Disponível | Ainda depende de desenvolvimento/integração |
|---|---|---|
| NICO | Resumo, sugestão, fontes e ações CRM revisadas | Monitoramento automático de mensagens |
| Comercial | Análise de qualificação e oportunidade/atividade aprovada | Sincronização BEMTEVI e acompanhamento automático |
| CX | Análise de manifestações e pendências fornecidas; tarefa CRM | Dados ERP, NPS persistido e modelo de churn validado |
| Suporte N1 | Procedimentos aprovados, orientação e tarefa interna | Consulta/abertura real Ksys Help Desk |
| Financeiro | Orientação com limitações explícitas e tarefa interna | Cobranças, segunda via, agenda e negociação |
| Implantação | Checklist sugerido e tarefa CRM | Checklist operacional persistido, PABX/portabilidade |
| Supervisor | Revisão da conversa e recomendação de intervenção | Supervisão global, orquestração e transferência automática |

Ana não foi atribuída a um perfil sem definição funcional. Campanhas e Pedidos/Pós-venda do DOCX permanecem entregas próprias.

## ERPs

Consulte `INTEGRACAO-ERP-BEMTEVI-HELPDESK.md`. O usuário informou ausência de base de homologação e uso de CNPJ como identificador empresarial. Credenciais foram configuradas em arquivo local ignorado e usadas em consultas autenticadas de leitura: CNPJ 28.240.080/0001-71 corresponde ao cliente BEMTEVI 152 e à empresa Help Desk 536. Adaptadores ERP e vínculos ainda não estão ativos nas conversas. Não houve abertura de chamado nem emissão de segunda via.

## Publicação e evidências

Código, testes e banco de homologação usam a cópia de desenvolvimento. O ZIP de 07/09 não contém estas alterações. A compilação da interface e a validação real desta etapa devem ser confirmadas pelas evidências `nico-specialist-*` antes de tratar a versão como publicada localmente.

Em 08/09, os testes de runtime (10), frontend (7), Rails de fundação (25), ações/runs/readiness (22) e a verificação posterior das propostas (7) passaram. A compilação transformou 5073 módulos e chegou à renderização dos arquivos, mas não houve confirmação de término: o Docker passou a retornar HTTP 500, com aproximadamente 100 MB livres no disco C:. A nova interface e os testes reais dos especialistas permanecem pendentes de recuperação do ambiente. O teste real anterior do NICO não comprova a publicação desta versão.

