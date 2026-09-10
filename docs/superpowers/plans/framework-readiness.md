# Prontidão dos frameworks — 7 de setembro de 2026

Revisão documental das versões declaradas/lockadas e das políticas oficiais consultadas nesta data. Não executou upgrade, instalação, Docker ou testes Rails. Um pin ajuda a repetir uma instalação; não prova manutenção, segurança, compatibilidade nem homologação de produção. Tags Docker sem digest também podem ser reconstruídas pelo publicador.

## Conclusão

**A base Rails 7.1 está fora de suporte de segurança e precisa de uma trilha de modernização antes de ser apresentada como base de produção mantida.** O trabalho NICO pode continuar na homologação isolada, preservando o baseline para verificar comportamento; não se deve confundir os testes funcionais desse baseline com aprovação da stack para exposição pública. Redis 7.4.0, Ruby 3.4.4 e Node 24.13.0 também estão atrás de releases publicados nas respectivas linhas.

## Matriz de decisão

| Componente encontrado | Manutenção em 2026-09-07 | Recomendação pragmática, ainda não aplicada |
| --- | --- | --- |
| Rails `7.1.5.2` no `Gemfile.lock` | A linha 7.1 encerrou segurança em **2025-10-01**. A linha 7.2 encerrou em **2026-08-09**. | Planejar destino em Rails **8.1.x** mantido, com releases intermediários como etapas de migração e testes. Não vender 7.2 como solução final. Rails 8.0 tem horizonte curto: segurança até 2026-11-07. |
| Ruby `3.4.4` no Gemfile/lock/Dockerfile | Linha 3.4 em manutenção normal. Download oficial oferece **3.4.10**. | Validar patch **3.4.10** na mesma linha, sincronizando Gemfile, lock, `.ruby-version` e imagens. Não migrar a Ruby 4 só por ser o mais recente. |
| Node `24.13.0` no compose NICO; `24-alpine` no Dockerfile do produto | Linha 24 é LTS; **24.20.0**, publicado em 2026-08-26, é o LTS atual consultado. | Padronizar uma versão 24.x atual validada e digest por imagem. Não migrar ao Node 26 Current somente por novidade. |
| Vue `^3.5.12`; lock principal `3.5.12`, outra resolução `3.5.13` | Vue não promete calendário LTS por minor; release estável oficial consultado **3.5.42**. | Atualização coordenada dos pacotes Vue/runtime/compiler dentro de 3.5, com testes e build. Evitar declarar suporte temporal fixo que o projeto não promete. |
| Vite `6.4.2` exato | **6.4 ainda recebe correções de segurança** pela política atual. `8.2` recebe patches regulares; npm latest consultado `8.2.2`. | Manter 6.4 como baseline controlado e acompanhar patches de segurança. Migração para 8 exige validar plugin Ruby, Vue e build; não é substituição automática necessária apenas por diferença de major. |
| PostgreSQL linha `16`, imagem `pgvector/pgvector:pg16` | PostgreSQL 16 suportado até **2028-11-09**; minor oficial atual **16.15**. | Confirmar o servidor efetivamente contido na imagem, atualizar minor compatível, fixar imagem/digest e testar extensão pgvector e restore. O tag `pg16` não prova qual minor está instalado. |
| Redis imagem **`redis:7.4.0-alpine`** | Linha 7.4 classificada Extended até **2029-12-01**. Release **7.4.11** publicado em 2026-08-17 contém correções de segurança. | Priorizar patch para 7.4.11 após validar Sidekiq/cache e persistência. A manutenção da linha não torna 7.4.0 atualizado. |
| elizaOS core/SQL **`1.7.2`** | Core npm `latest` confirmado 1.7.2 nesta consulta; SQL depende exatamente desse core. Não foi localizada política de LTS/EOL equivalente à dos bancos/frameworks. | Manter pins e lock sob revisão de dependências, sem prometer SLA upstream. Preservar runtime privado e modelo/plugin limitado; não saltar para GitHub main/beta. |

Fontes oficiais que sustentam a matriz:

- Rails: [anúncio com encerramento de 7.1 e 7.2](https://rubyonrails.org/2024/10/15/new-maintenance-policy-and-eol-annouments), [política atual e datas 8.0/8.1](https://rubyonrails.org/maintenance). A página ainda lista 7.2 entre releases de segurança, mas sua própria data 2026-08-09 já passou; a classificação acima considera a data desta revisão.
- Ruby: [estado das branches](https://www.ruby-lang.org/en/downloads/branches/), [downloads 3.4.10](https://www.ruby-lang.org/en/downloads/), [3.4.9 com atualização de zlib para CVE-2026-27820](https://www.ruby-lang.org/en/news/2026/03/11/ruby-3-4-9-released/). O advisory de zlib não prova sozinho vulnerabilidade do bundle local: a versão efetivamente resolvida da gem também importa.
- Node: [política e linhas LTS](https://nodejs.org/en/about/previous-releases), [release 24.20.0](https://nodejs.org/en/blog/release/v24.20.0).
- Vue: [política de releases e compatibilidade compiler/runtime](https://vuejs.org/about/releases.html), [release 3.5.42](https://github.com/vuejs/core/releases/tag/v3.5.42).
- Vite: [política com suporte de segurança 6.4](https://vite.dev/releases), [release 6.4.2](https://github.com/vitejs/vite/releases/tag/v6.4.2), [manifest publicado atual](https://registry.npmjs.org/vite/latest).
- PostgreSQL: [política e tabela das versões suportadas](https://www.postgresql.org/support/versioning/).
- Redis: [política Open Source, não Redis Enterprise](https://redis.io/docs/latest/operate/oss_and_stack/install/version-mgmt/), [7.4.11 e correções de segurança](https://github.com/redis/redis/releases/tag/7.4.11).
- elizaOS: [manifest core 1.7.2](https://registry.npmjs.org/@elizaos/core/1.7.2), [manifest SQL 1.7.2](https://registry.npmjs.org/@elizaos/plugin-sql/1.7.2); detalhes de API/empacotamento no relatório local `eliza-runtime-research.md`.

## Por que Rails exige um trabalho próprio

Não basta mudar a versão de Rails no Gemfile. Restrições observadas no lock atual impedem essa troca isolada:

- `administrate-field-belongs_to_search 0.9.0`: `rails >=4.2, <7.2`.
- `administrate 0.20.1`: `actionpack`, `actionview` e `activerecord <8.0`.
- `devise_token_auth 1.2.5`: `rails <8.1`.
- O trecho de `devise-two-factor 6.1.0` também fixa componentes ActiveSupport/Railties `<8.1`.

A decisão necessária é compatibilizar, atualizar ou substituir essas integrações mantendo autenticação, painel administrativo e extensões Chatwoot/JRC. Não foi verificada aqui a existência de releases substitutos compatíveis e, portanto, nenhum pin deles é proposto. A migração deve ter testes de login, token, 2FA, policies entre contas, ActiveJob/Sidekiq, ActionCable, campanhas, migrations e build Vue; atualizações de defaults Rails devem ser controladas. O destino 8.1 é uma recomendação de linha com horizonte de manutenção, não uma afirmação de compatibilidade já comprovada.

## Ordem proposta de homologação

1. Preservar o baseline atual e resultados NICO para comparação, sem exposição pública nova. Separar aceitação funcional NICO da aceitação da stack para produção.
2. Priorizar patches de Redis/Ruby/Node e resolução das vulnerabilidades transitivas confirmadas; cada mudança produz lock/imagem verificável, build e smoke adequados. Capturar digest/versão efetiva do PostgreSQL. Não executar `update` irrestrito em todos os gerenciadores.
3. Modernizar Rails com as restrições acima resolvidas e testes de regressão do produto. Rails 7.2 pode ser etapa de upgrade, mas já não é destino mantido nesta data.
4. Atualizar Vue de forma coordenada; tratar Vite 8 como migração de build própria. Servir artefatos de produção, não servidor de desenvolvimento Vite.
5. Para elizaOS, conservar a fronteira privada, contexto pré-autorizado, logs sem conteúdo sensível, limites e revisão de dependências. A auditoria realizada nesta sessão demonstrou que `npm install` pode deixar um override aninhado inválido: verificar `npm ls`, audit e lock, não apenas a mensagem de instalação.

Não houve atualização ou homologação dessas versões candidatas neste relatório. Também não foi feita auditoria completa de CVEs de todas as gems, npm, sistema operacional ou imagem: suporte da linha e presença de pin são evidências diferentes de ausência de vulnerabilidades.
