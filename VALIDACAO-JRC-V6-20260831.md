# Relatório de validação estática — JRC Conversas V6

**Versão analisada:** `JRC-CAMPANHAS-LAYOUT-V6-CRM-COPILOTO-ATENDIMENTO-PRODUTOS-PROPOSTAS-20260831`  
**Data:** 31/08/2026

## Resultado

A estrutura da V6 foi preparada e validada estaticamente. Isso confirma integridade de sintaxe e consistência estrutural dos arquivos revisados, mas não substitui a homologação da aplicação em Docker.

## Validações concluídas

- sintaxe Ruby dos controllers, models, serializers, services, migration, rotas, schema e specs alterados;
- sintaxe JavaScript dos arquivos `.js` e dos blocos `<script>` dos componentes Vue alterados;
- balanceamento estrutural das tags e ausência de atributos duplicados nos templates Vue alterados;
- estrutura Ruby do template público ERB, incluindo o bloco Rails `form_with`;
- equilíbrio dos delimitadores ERB;
- referências literais às rotas utilizadas pelos novos módulos;
- ausência de timestamps e classes duplicadas nas migrations;
- presença e leitura dos ativos do mascote;
- ausência de referências ativas a ERP/Bentevi no código desta versão;
- atualização do `db/schema.rb` para a migration da V6;
- adição de specs para Produtos e Propostas;
- exclusão planejada de `.env`, logs, temporários e caches do ZIP final.

## Correções de consistência incluídas durante a validação

- remoção de método duplicado no serviço do Copiloto;
- correção do cálculo do desconto comercial para não descontar duas vezes o desconto dos itens;
- limitação do desconto comercial ao saldo líquido, impedindo total negativo;
- validação de preço mínimo também nos itens da proposta;
- bloqueio da aprovação depois do aceite;
- exigência de nome e documento no aceite interno;
- configuração inicial de 20% de desconto máximo e aprovação acima de 10% no novo cadastro visual;
- atualização do schema para novos campos e índices.

## Não executado neste ambiente

As seguintes validações não puderam ser executadas porque este ambiente não possui Docker, Bundler, gerenciador JavaScript nem dependências instaladas:

- `bundle install` / `bundle check`;
- suíte RSpec;
- instalação de pacotes e build Vite;
- `docker compose config`, `up`, `ps` e logs;
- `rails db:prepare`;
- testes de interface no navegador;
- chamadas reais da Meta, PABX, e-mail e IA.

## Critério de uso

O ZIP deve ser tratado como **versão de desenvolvimento pronta para homologação local**, e não como versão já aprovada para produção. A publicação no servidor deve ocorrer somente depois da validação local de login, CRM, banco, Sidekiq, Vite, Produtos, Propostas, Conversas, Campanhas, PABX/Ramal, WhatsApp Calling e Copiloto.
