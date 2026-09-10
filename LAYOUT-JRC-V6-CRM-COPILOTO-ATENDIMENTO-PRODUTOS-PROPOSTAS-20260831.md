# JRC Conversas — V6 CRM, Copiloto, Atendimento, Produtos e Propostas

**Versão:** 31/08/2026  
**Base preservada:** `JRC-CAMPANHAS-LAYOUT-V5-CRM-CALENDAR-CONVERSAS-CALLING-20260831`  
**Nova pasta:** `JRC-CAMPANHAS-LAYOUT-V6-CRM-COPILOTO-ATENDIMENTO-PRODUTOS-PROPOSTAS-20260831`

## 1. Objetivo desta versão

A V6 consolida as alterações solicitadas nos textos e nas imagens de referência, sem substituir a identidade original da JRC e sem remover os módulos já existentes de Conversas, CRM, Campanhas, PABX/Ramal, WhatsApp Calling e Videoconferência.

Decisões específicas desta entrega:

- remover ERP/Bentevi do escopo do catálogo e das propostas;
- separar logicamente Central de Atendimento, Conversas, E-mails, Chamadas e Contatos;
- criar o Copiloto JRC como inteligência operacional contextual;
- adotar o mascote-nuvem fornecido pelo usuário, mantendo o logotipo original da JRC separado e preservado;
- ampliar Produtos para produtos, serviços, licenças, projetos e recorrência;
- fazer os totais das Propostas derivarem dos itens, implantação, recorrência e descontos;
- manter os estados apresentados ao usuário em português.

## 2. Nova organização de Atendimento

A barra lateral foi reorganizada para apresentar:

### Atendimento

- Central de Atendimento;
- Conversas;
- E-mails;
- Chamadas;
- Contatos.

### Inteligência

- Copiloto JRC.

A **Central de Atendimento** funciona como cockpit e mostra pendências e acessos aos canais. O módulo **E-mails** lista somente caixas de e-mail configuradas. O módulo **Chamadas** separa Ramal JRC, WhatsApp Calling e histórico quando disponível.

## 3. Copiloto JRC

O Copiloto foi implementado em duas formas:

- botão flutuante contextual em todas as telas internas;
- página própria `Copiloto JRC` na navegação lateral.

O assistente recebe o nome e o caminho da tela atual e oferece orientação para:

- Central de Atendimento;
- Conversas;
- E-mails;
- Chamadas;
- Contatos;
- Visão Geral e Indicadores do CRM;
- Leads, Negócios, Funil e Minha Carteira;
- Atividades e Agenda;
- Produtos e Propostas;
- Campanhas;
- Ramal e WhatsApp Calling.

### Operação com e sem chave de IA

- Com uma credencial OpenAI válida, o Copiloto usa IA para responder de forma contextual.
- Sem credencial, ele continua funcionando como **guia inteligente local**, usando um catálogo de tarefas e direcionamentos seguros.
- O Copiloto não afirma que enviou, ligou, sincronizou ou executou uma integração sem confirmação real da aplicação.
- A chamada do Copiloto não consome a cota de respostas do Captain.

### Variáveis de ambiente

```env
OPENAI_API_KEY=
OPENAI_BASE_URL=https://api.openai.com/v1
JRC_COPILOT_MODEL=
```

O modelo é opcional; quando o campo fica vazio, a aplicação usa o roteamento/modelo padrão configurado para os recursos de IA. Também é possível utilizar uma integração OpenAI habilitada na conta ou a chave de instalação já configurada para esses recursos.

### Arquivos principais

```text
app/controllers/api/v1/accounts/jrc_copilot_controller.rb
app/services/jrc_copilot/assistant_service.rb
app/services/jrc_copilot/task_catalog.rb
app/javascript/dashboard/api/jrcCopilot.js
app/javascript/dashboard/components-next/jrcCopilot/
app/javascript/dashboard/routes/dashboard/jrcCopilot/
```

## 4. Identidade do mascote

Foram adicionados os seguintes ativos:

```text
public/brand-assets/jrc-copilot-concept.jpg
public/brand-assets/jrc-copilot-avatar.png
public/brand-assets/jrc-copilot-character.png
public/brand-assets/jrc-copilot-thinking.png
```

O mascote é a própria nuvem azul da JRC transformada em personagem. O logotipo institucional original continua disponível em `public/brand-assets/logo-jrc.png` e não foi substituído.

## 5. Catálogo de Produtos

O cadastro foi ampliado para comportar:

- produto, serviço, licença e projeto;
- categoria, subcategoria, SKU, descrição e tags;
- cobrança única, mensal, anual ou por uso;
- preço, custo, preço mínimo, margem, impostos e comissão;
- setup/implantação;
- quantidade mínima e quantidade variável;
- franquia, unidade incluída, excedente e rollover;
- prazo de ativação e período de validação;
- vigência contratual;
- desconto máximo e limite para aprovação;
- renovação, reajuste e multa de cancelamento;
- disponibilidade por empresa;
- integrações internas com Financeiro, Contratos e Implantação;
- modelo de proposta e contrato;
- observações comerciais, requisitos técnicos e escopo incluído/excluído;
- indicadores, filtros, importação CSV e exportação.

ERP/Bentevi não faz parte do modelo, da interface nem do catálogo de integrações desta V6.

## 6. Propostas Comerciais

A proposta foi ampliada com:

- número da proposta e versão;
- empresa emissora, CNPJ/unidade e responsável;
- datas, validade e vigência;
- forma de pagamento, vencimento e primeiro faturamento;
- impostos, reajuste, renovação e multa;
- itens com produto, quantidade, unidade, cobrança, implantação, recorrência, desconto, franquia, excedente e prazo de ativação;
- cálculo automático de implantação, recorrência mensal, descontos e total do primeiro mês;
- aprovação comercial, financeira e técnica;
- prévia, PDF, download, link público, WhatsApp e e-mail;
- contagem e data de visualização;
- aceite digital com nome, documento, data, hora, IP e bloqueio após aceite;
- duplicação para nova versão;
- histórico de eventos.

### Regra de cálculo

Os valores manuais de implantação e mensalidade continuam disponíveis apenas enquanto a proposta não possui itens. Depois que itens são adicionados, implantação, recorrência, subtotal, descontos e total são recalculados pelos itens.

O desconto comercial geral é limitado ao saldo líquido disponível, impedindo total negativo. O preço do item não pode ficar abaixo do preço mínimo cadastrado e o desconto não pode ultrapassar o limite do produto.

## 7. Banco de dados

Nova migration:

```text
db/migrate/20260831120000_expand_jrc_crm_catalog_and_proposals.rb
```

O `db/schema.rb` foi atualizado para a versão `2026_08_31_120000`.

A migration amplia:

- `jrc_crm_products`;
- `jrc_crm_proposals`;
- `jrc_crm_proposal_items`.

## 8. Testes adicionados

```text
spec/models/jrc_crm/product_spec.rb
spec/models/jrc_crm/proposal_spec.rb
```

Os testes cobrem regras de equivalência mensal, preço mínimo, integrações internas permitidas, composição automática da proposta, limites de desconto e bloqueio após aceite.

## 9. Subida local recomendada

A V6 preserva os mapeamentos locais da V5:

- Rails: `3007 -> 3000`;
- Vite: `3043 -> 3036`;
- PostgreSQL: `55447 -> 5432`;
- Redis: `56395 -> 6379`;
- Mailhog SMTP: `1032 -> 1025`;
- Mailhog Web: `8033 -> 8025`.

Use um nome de projeto Docker próprio para não misturar a V6 com versões anteriores:

```bat
cd /d "C:\Users\DEV03\Desktop\Atualizações\JRC-CAMPANHAS-LAYOUT-V6-CRM-COPILOTO-ATENDIMENTO-PRODUTOS-PROPOSTAS-20260831"
```

```bat
docker compose -p jrc-campanhas-layout-v6 config -q
```

```bat
docker compose -p jrc-campanhas-layout-v6 up -d
```

```bat
docker compose -p jrc-campanhas-layout-v6 ps
```

Somente depois de Rails e PostgreSQL estarem estáveis:

```bat
docker compose -p jrc-campanhas-layout-v6 exec rails bundle exec rails db:prepare
```

## 10. Limites de homologação

Esta entrega contém código, migration, interface e validações estáticas. Ainda precisam ser testados em execução:

- instalação das dependências Ruby e JavaScript;
- build Vite;
- subida de Rails, Sidekiq, PostgreSQL, Redis e Mailhog;
- migration em um banco de teste da V6;
- login e permissões;
- CRUD de Produtos e Propostas;
- PDF e link público;
- envio por e-mail/WhatsApp em uma conversa real;
- WhatsApp Calling com número e permissões Meta válidos;
- PABX/Ramal com credenciais válidas;
- resposta real da IA com uma chave configurada.

Não executar `docker compose down -v` em uma versão que tenha dados a preservar.
