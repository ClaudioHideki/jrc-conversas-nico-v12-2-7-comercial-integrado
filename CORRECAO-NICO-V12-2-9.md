# NICO V12.2.9 — correção de interpretação e execução JSON

Entrega para validação local em 14/09/2026. Nenhuma publicação, release, implantação em produção, envio a terceiros ou chamada real à OpenAI foi realizada nesta validação.

## 1. Base e integridade

Base exclusiva: `jrc-conversas-nico-v12-2-7-comercial-integrado-main (3).zip`, 81.947.752 bytes.
SHA-256: `0e8d7e18e244ffef0e045d5c14428f2bc6702dacb9c4d508236a7fa292a1f7c4`.
Todos os CRCs do ZIP foram verificados; a extração ocorreu em pasta nova. A raiz real é `jrc-conversas-nico-v12-2-7-comercial-integrado-main/`. O AGENTS.md foi lido integralmente. Os cinco hashes fornecidos da produção conferem exatamente e estão registrados no manifesto. O ZIP original foi preservado.

Foram examinados os doze arquivos solicitados, o fluxo HTTP, o controlador, a interface, a contabilização e os testes existentes. A busca em `enterprise/` não encontrou um overlay correspondente do NICO. Os jobs/modelos de continuação existentes não precisaram de alteração.

## 2. Causa raiz

O Structured Output define `arguments` como string. Esse schema garante uma string externa, mas não garante que seu conteúdo seja JSON válido. `validateOperationResult` fazia até três JSON.parse sobre essa string, sem capturar SyntaxError. O erro escapava como 502; o servidor perdia sua categoria e o Rails/painel a substituíam por uma mensagem genérica. A versão e a permissão da conta não explicam essa falha: os hashes confirmam a base de produção indicada.

Havia ainda um trecho que incluía prévia do corpo inválido do provedor em uma exceção; essa prévia foi eliminada. Não há reparo heurístico nem remoção de cercas Markdown do JSON.

## 3. Solução e limites

- `parseToolArguments` interpreta uma vez, captura erros e exige objeto na raiz: arrays, null e primitivos são rejeitados. Limite de 12.000 bytes UTF-8 e oito níveis contando raiz/valores; números não finitos ou inteiros fora da faixa segura também são rejeitados. O Rails aplica a mesma fronteira antes do catálogo e do executor.
- O contrato de sucesso conserva `arguments` como string no HTTP; o RuntimeClient transforma o objeto validado em Hash. Campos e tipos das ferramentas continuam sujeitos ao ToolCatalog. Ferramentas desconhecidas nunca viram chamadas arbitrárias.
- Operações recebem no máximo duas chamadas ao provedor: uma inicial e uma repetição apenas para JSON externo, JSON interno ou schema inválidos. As duas compartilham contexto, request_id e um único prazo de 45 segundos. Cancelamento encerra a chamada. 401, 403, 429, 5xx e falhas de transporte não disparam essa repetição.
- O runtime apenas planeja; não executa ferramentas. O Rails só recebe um resultado utilizável após validação completa. Não há repetição do POST Rails→runtime, de confirmação, de escrita ou de envio ao cliente nessa correção.
- Mantido o teto de 2.000 tokens de saída por chamada; duas chamadas permitem no máximo 4.000 tokens de saída. O Rails reserva antecipadamente as duas tentativas: `2 * (bytes_do_payload + 16.000)`, recusando contextos acima do teto de 270.000 tokens. O uso medido é somado. Se o envelope externo inválido não contém uso recuperável, a tentativa é contabilizada conservadoramente e marcada `usage_estimated=true` na resposta e nos metadados do UsageEvent. Esse valor exige conciliação administrativa, não representa medição exata do provedor. Falhas finais preservam a reserva para conciliação, como no fluxo anterior.
- Confirmações, locks, IDs de requisição, expiração de prévias, estados `unknown` e controle do job de continuação foram preservados. Uma falha depois de uma escrita confirmada informa que as etapas anteriores permanecem concluídas; não afirma desfazer registros.
- `count_contacts` e `list_contacts` já existiam sem query/filtro obrigatório e foram preservados e testados repetidamente.
- Contatos encontrados incluem telefones e conversas/canais visíveis. Busca com duplicidades retorna opções reais e bloqueia a preparação de destinatário ambíguo até indicação de `contato #ID` ou seleção de uma conversa. O cache de histórico revalida também essas conversas.
- Criar lead por contato reutiliza o único lead visível existente sem sobrescrever notas; se houver vários, pede escolha. Criar reunião continua sujeito a confirmação, vínculo, fuso e conflito de horário. O comprovante informa que não houve convite externo.
- Novo `conversation_opportunity_batch`: consulta somente leitura, dez conversas por lote, até cinco mensagens públicas de até 300 caracteres por conversa. Todos os status por padrão. Mantida a janela de até 200 conversas recentes da conta, filtrada pela política do usuário; não é leitura de todo o histórico nem garantia de encontrar todas as oportunidades. Retorna IDs, leads vinculados e next_page. Há até oito turnos de planejamento (no máximo sete consultas); o último é reservado à síntese, antecipada quando o contexto excede 80.000 bytes. Se o modelo não concluir, a resposta lista alcance, IDs e limite, sem a antiga frase genérica nem alegação de análise concluída.

## 4. Códigos e mensagens

| Situação | Código técnico |
| --- | --- |
| Envelope do provedor ou conteúdo externo não JSON | `provider_outer_json_invalid` |
| JSON interno inválido ou fora dos limites | `tool_arguments_invalid` |
| Estrutura incompatível | `provider_schema_invalid` |
| Prazo do provedor | `provider_timeout` |
| HTTP 401 / 403 do provedor | `provider_unauthorized` / `provider_forbidden` |
| HTTP 429 do provedor | `provider_rate_limited` |
| HTTP 5xx ou rejeição HTTP restante | `provider_unavailable` |
| Rede até o provedor | `provider_transport_error` |
| Contabilização inválida | `provider_usage_invalid` |
| Runtime ocupado | `runtime_busy` |
| Conta fora da lista do runtime | `account_not_configured` |
| Autenticação Rails→runtime recusada | `unauthorized` |
| Falha de rede / prazo Rails→runtime | `runtime_transport_error` / `runtime_timeout` |
| Cancelamento | `request_cancelled` |

Os logs de falha usam campos permitidos e códigos fixos; não incluem corpo de conversa, resposta integral do provedor, stack, chave, token, credenciais ou Authorization. O Rails aceita somente códigos conhecidos da resposta de erro. O painel exibe a mensagem segura do servidor, tanto em Quick como em Full.

Após duas interpretações inválidas, uma ação nova informa: “O NICO não conseguiu interpretar os dados necessários para executar esta ação. Nenhuma alteração foi realizada. Tente novamente ou revise os dados informados.” Limite, indisponibilidade, autenticação e timeout têm mensagens correspondentes.

## 5. Arquivos adicionados

- `services/nico-runtime/src/errors.ts`
- `services/nico-runtime/src/provider.ts`
- `services/nico-runtime/test/provider-reliability.test.ts`
- `services/nico-runtime/test/operation-http.test.ts`
- `services/nico-runtime/test/fixtures/provider-preload.mjs`
- `services/nico-runtime/test/fixtures/operation-contract.json`
- `spec/requests/jrc_nico_json_reliability_spec.rb`

Documentação e evidências adicionadas: este arquivo, `NICO-V12-2-9-MANIFEST.json`, `SHA256SUMS` e `docs/validation/nico-v1229/{runtime.log,rails.log,frontend.log,correction.diff}`.

## 6. Arquivos modificados e removidos

- `app/controllers/api/v1/accounts/jrc_nico/operations_controller.rb`
- `app/javascript/dashboard/components-next/jrcCopilot/JrcCopilotPanel.vue`
- `app/javascript/dashboard/components-next/jrcCopilot/specs/nicoQuickUI.spec.js`
- `app/services/jrc_nico/operational_inference.rb`
- `app/services/jrc_nico/operator_session.rb`
- `app/services/jrc_nico/runtime_client.rb`
- `app/services/jrc_nico/tool_catalog.rb`
- `app/services/jrc_nico/tool_executor.rb`
- `services/nico-runtime/package.json`
- `services/nico-runtime/src/engine.ts`
- `services/nico-runtime/src/operations.ts`
- `services/nico-runtime/src/server.ts`
- `spec/services/jrc_nico/runtime_client_spec.rb`

Removidos: nenhum. Dos 9.394 arquivos originais, 9.381 permanecem byte a byte idênticos. Nenhuma migration foi criada/alterada. Os demais módulos, imagens, integrações, PostgreSQL, Redis, Sidekiq, permissões, catálogo e configurações da base foram preservados. Há normalização de estilo/terminação de linha somente nos arquivos já alterados. Não foram incluídos caches, node_modules ou dados gerados pelos testes. O projeto será compilado pelos Dockerfiles existentes; o ZIP contém o código completo, não uma imagem Docker pré-construída.

## 7. Testes executados e resultados

| Verificação final | Resultado |
| --- | --- |
| Runtime: `npm run lint` | Aprovado; TypeScript com noUnusedLocals/noUnusedParameters |
| Runtime: `npm run typecheck` | Aprovado |
| Runtime: `npm run build` | Aprovado |
| Runtime: `npm test` | 31 testes, 31 aprovados |
| Rails: `bundle exec ruby scripts/nico-specs.rb spec/services/jrc_nico spec/jobs/jrc_nico spec/requests/jrc_nico*_spec.rb` | 121 exemplos, zero falhas |
| Interface: Vitest com `--config vitest.nico.config.ts --no-cache` | 61 testes em oito arquivos, todos aprovados |
| ESLint dos dois arquivos alterados da interface | Zero erros; 16 avisos de estilo/i18n em trechos existentes |
| `ruby -c` nos oito fontes relacionados e dois specs afetados | Dez verificações aprovadas |
| CRC do ZIP, cinco hashes de produção e preservação de módulos | Aprovados |

O Node usado nos containers foi 24.13.0; Ruby 3.4.4. As dependências vieram dos caches/volumes locais, montados somente para leitura. PostgreSQL/Redis de teste estavam numa rede interna e banco `nico_v1229_test` temporário; sem seeds de produção. Todos os testes de provedor usam mocks/fixtures. Não houve consumo da API real da OpenAI nem ligações, convites ou mensagens reais a clientes.

Cobertura solicitada: resposta válida inicial; inválida interna seguida de válida; duas inválidas; nenhuma ferramenta exposta/executada em falha; confirmação única; contagem/lista sem query; ferramenta inexistente; campos desconhecidos; tipos incorretos; confirmações de escrita; continuação após confirmação; 429; timeout/cancelamento; logs redigidos; fixture compartilhada entre TypeScript e Ruby. O teste HTTP usa o engine ElizaOS real com fetch simulado e confirma duas tentativas pelo uso agregado.

Também foram testados Telmo com/sem lead existente, data “amanhã 10h” em America/Sao_Paulo (13h UTC), repetição de confirmação/job sem duplicatas, interrupção segura depois de uma escrita, duplicidade de contatos, todos os status de conversa, notas privadas excluídas, escopo de caixa do agente, revalidação do histórico e limite de lotes. Esses cenários validam o encadeamento com decisões simuladas do modelo; não são prova de interpretação perfeita do gpt-4.1-mini em produção.

As primeiras rodadas encontraram ajustes nas fixtures (mensagem recebida reabre conversas; mock de ramal precisava de registered) e na configuração de execução do Vitest. Os resultados acima correspondem às rodadas finais corrigidas. Avisos de deprecação Rails/Rack e Browserslist existentes não foram tratados por estarem fora desta correção.

## 8. Riscos residuais

- O provedor ainda pode produzir dados inválidos duas vezes ou uma interpretação semanticamente inadequada. Nesse caso a execução deve parar ou exigir revisão; a correção não transforma linguagem natural em garantia de acerto.
- Consultas extensas são amostras limitadas. Pedir continuação por next_page e conferir IDs/alcance. Paginação em dados que mudam durante a consulta não é um snapshot transacional.
- Fluxos longos podem consumir mais tempo/cota por envolver várias consultas, cada qual sujeita ao prazo de 45 segundos. O timeout do proxy e as cotas existentes precisam comportar o uso real; não foram alterados.
- UsageEvent com usage_estimated precisa ser conciliado; erros com resultado incerto não devem ser repetidos como escrita.
- Não foi construído nem implantado o conjunto completo de imagens de produção neste trabalho. Compilar Rails/assets, runtime e atualizar Sidekiq faz parte da homologação/implantação. Os demais módulos foram preservados por comparação de arquivos, não por teste ponta a ponta de cada integração externa.

## 9. Roteiro seguro de implantação (somente após aprovação)

1. Validar o SHA-256 externo do ZIP e, após extrair, os arquivos com `sha256sum -c SHA256SUMS` em Linux. Ler este documento e o manifesto; documentos anteriores no repositório são históricos.
2. Em homologação isolada, construir imagens novas com os Dockerfiles existentes: Rails em `docker/Dockerfile`, runtime em `docker/nico-runtime.Dockerfile`, ambos com o contexto na raiz do projeto. Compilar os assets do Rails. Usar tag imutável V12.2.9, não sobrescrever a tag anterior.
3. Guardar os digests/imagens anteriores e backup operacional do banco/configurações. Preservar URLs, volumes, integrações, chaves e tokens existentes no gerenciador de segredos; o ZIP não os substitui. Não executar seeds nem restaurar dados de teste em produção.
4. Validar localmente com conta e contatos de homologação: repetir as quatro consultas; mostrar os contatos duplicados; selecionar explicitamente o contato/conversa; confirmar lead e reunião separadamente; repetir confirmação e verificar um único registro; analisar lotes e conferir escopo. Testar indisponibilidade com mocks, sem expor credenciais. Testes manuais com provedor real devem ser feitos apenas na homologação autorizada.
5. Após autorização, pausar novas solicitações/delegações do NICO e aguardar escritas em andamento. Atualizar Rails/web e workers Sidekiq para a mesma imagem nova e depois o runtime, durante a pausa. Não executar um rollout misturando contratos: a resposta com usage_estimated exige o RuntimeClient novo. Nenhuma migration nova é necessária.
6. Conferir os hashes dos cinco arquivos nos containers contra os valores `after_sha256` do manifesto; conferir que o runtime foi compilado do mesmo source. `/health` só indica serviço pronto, não valida credenciais do provedor. Verificar autenticação, conta permitida e depois uma consulta controlada em homologação.
7. Retomar gradualmente. Observar os códigos, falhas, latência, cota, estados de comandos e IDs reais. Conferir que a mensagem específica aparece na interface atualizada. Não reenviar automaticamente comandos `unknown`.

## 10. Rollback

1. Pausar novos pedidos e delegações, aguardar comandos em execução e registrar seus IDs/estados. Não reenfileirar escritas já concluídas ou incertas.
2. Restaurar o runtime anterior e as imagens anteriores de Rails/web/Sidekiq de forma coordenada enquanto o NICO permanece pausado; usar os digests guardados. Restaurar também os assets da imagem anterior e recarregar o navegador.
3. Manter os volumes e o banco. Esta correção não exige reversão de migration nem restauração destrutiva do banco; contatos/leads/atividades legitimamente criados após a implantação devem permanecer.
4. Verificar saúde, autenticação e uma consulta de homologação. Conferir os hashes originais do manifesto. Retomar após revisão dos comandos pendentes; o rollback reintroduz a limitação de JSON que motivou esta correção.

## Conferência do pacote

`SHA256SUMS` cobre todos os arquivos entregues, exceto ele próprio. O hash do ZIP fica no arquivo externo `.zip.sha256` e cobre inclusive SHA256SUMS. `NICO-V12-2-9-MANIFEST.json` lista arquivos alterados/adicionados e hashes antes/depois. Arquivos de código não relacionados e configurações não foram substituídos por outra versão.
