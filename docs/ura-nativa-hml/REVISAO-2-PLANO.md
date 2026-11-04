# Revisão 2 — reconstrução visual OIA, 04/11/2026

## Destino e continuidade

O usuário alterou explicitamente o destino para `ClaudioHideki/jrc-conversas-nico-v12-2-7-comercial-integrado`. A origem funcional continua sendo `ClaudioHideki/jrc-conversas-lab2`; Broker/Flow continua sendo `ClaudioHideki/BrokerJRCIA`. O antigo destino GoPure é referência da entrega anterior, sem nova publicação nesse repositório.

- Destino original: `62c14af884c7f45fa640345556f2ffecc22113d8`, ancestral comprovado do trabalho anterior e do LAB2 atual.
- Trabalho anterior preservado integralmente: `5b2264a5b6c6af3dad6f43df66b9287420158cea`.
- LAB2: consolidado `a30fb50e6e53f1bc9eebe66ce50d13e46820b1c8`; main atual `5798160235e95e6b84e01c1d62d172e9d2a26c76`, com três ajustes posteriores de gates/manifests/fixtures e estilo.
- Broker: `13e8525a0103a00cada4864acba46a654cf9471b`, preservado na branch existente. A main remota também contém essa revisão na consulta de hoje.
- Branch do novo destino: `codex/ura-nativa-hml-20261104`. Nenhuma alteração de main ou tag antiga está prevista.

## Arquitetura e comportamento aprovado

Broker é o único executor. Conversas mantém configuração, histórico, atendimento humano e CSAT. A reconstrução se chama **OIA — RECONSTRUÇÃO VISUAL HML — PARIDADE PARCIAL**. Não usa Typebot, Bot Bridge ou Budibase em execução/administração do fluxo novo; seus cadastros não certificam a substituição de todo o provisionamento antigo.

As 23 imagens foram abertas e inspecionadas. ZIP com 21 JPEGs e SHA256 `08f3342529faaace9458a3538243dbd4fe2c06f35344c9a43552302c03ffffdb`, mais dois avulsos. Originais ficam exclusivamente fora dos repositórios. Índice e matrizes versionados conterão observações sanitizadas, sem nomes pessoais, telefones, HMAC, SIDs, tokens ou URLs antigas de operação.

Fluxo: expediente → aviso único quando fechado → saudação única → idioma → departamento canônico → opção de agente → anúncio → handoff nativo confirmado. Português e inglês compartilham entidades canônicas. São 2/4/4/3 posições por idioma, 26 combinações e oito retornos. O retorno não cria sessão nem repete saudação. Opção inválida conserva o texto original e reapresenta o menu, com política HML explicitamente identificada.

Os horários finais estão truncados nas capturas. `America/Sao_Paulo` é o fuso demonstrado; 08h–18h não será certificado como grade produtiva. Catálogo, exceções, fallback e parâmetros de espera de teste serão separados dos parâmetros desconhecidos do legado.

Handoff usa um agente OU um time por ação, com revisão/membership e leitura canônica. A escolha de pessoa conserva o departamento no contexto. Configuração incompatível de saudação/autoatribuição/AgentBot deve bloquear a ativação. Humano tem prioridade; não repetir atribuição, abertura ou texto após perda de autoridade. Não declarar que a ausência absoluta de corrida remota é garantida.

CSAT reutiliza o mecanismo existente do Conversas: convite/link HTTPS próprio, resposta escopada, uma pesquisa por conversa e sem reinício da URA por convite, resposta ou callback. Distinguir conversas do mesmo contato.

## Plano verificável

1. **Integração:** manter todos os commits anteriores e integrar somente as nove alterações posteriores pertinentes do LAB2, conciliando os gates do novo destino. Conferir branding por conta e Enterprise.
2. **Broker:** reconstrução nativa configurável, catálogo HML, 26 percursos e oito retornos; completar a política de menu necessária sem alterar a semântica dos grafos publicados antigos. Testar invalidez, expediente, persistência, versão, duplicação e ordenação.
3. **Handoff:** usar os contratos de atribuição existentes; testar agente exato (inclusive opções 2 e 3 de Porto Alegre), revisão/catalogo revogados, bot enfileirado e ação humana concorrente. Manter configurações incompatíveis bloqueadas.
4. **Conversas/CSAT:** regressão de convite único sob eventos repetidos/concorrentes, reabertura, duas conversas e duas contas. Verificar transporte, link/resposta e ausência de competição com Flow. Não segurar transação durante chamada externa.
5. **Fuso:** configurar explicitamente o consumo de `APP_TIME_ZONE`, preservar persistência UTC e `TZ=UTC` dos testes, e provar `Time.zone`/`Time.current` em Rails e Sidekiq nas imagens de HML.
6. **Interface:** disponibilizar criação/edição do fluxo reconstruído pelo editor integrado; oferecer caminho compreensível para Flow na configuração de robô, sem criar AgentBot externo fictício.
7. **Ambiente:** completar Compose/env/runbook e verificar recursos isolados. O usuário indicou o serviço Dokploy `jrcconversas-lab-app` e o frontend `https://jrcconversas-lab.jrcws.cloud`. Inspecionar imagem, banco, volumes, rede e dados existentes antes de aplicar; domínio com nome lab não comprova isolamento. Origem Broker HML e número/contato/conta/caixa ainda precisam ser identificados.
8. **Verificação e publicação:** TDD para mudanças; gates de ambos os repositórios; editor gerado da fonte Broker commitada; imagens novas por SHA/digest; smoke e verificações possíveis nas imagens finais. Sem replay/backup/restore produtivo.
9. **Entrega:** índice IMG_01–IMG_23, correspondência bots/instâncias, matrizes OIA01–OIA13 e T01–T20, 26 resultados individuais, manifestações de origem/imagens e checkpoint. Separar código/automatizado/imagem/HML integrada/WhatsApp real/paridade cliente.

## Dependências externas

Paridade integral OIA, CRF, Íris e demais bots permanece bloqueada pelos exports publicados, contratos Bridge/configurações completas e inventário não visível. O export OIA/Teste anterior é referência adicional; não comprova a identidade do fluxo OIA publicado nas capturas. Não inferir regras de ERP/IA a partir de texto de atendimento.

O frontend/serviço Dokploy foram informados; ainda não há prova de isolamento dos recursos nem identificação completa do Broker HML, conta/caixa e contato de teste. Continuar as etapas independentes enquanto essas verificações são resolvidas.
