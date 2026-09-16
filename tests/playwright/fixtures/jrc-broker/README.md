# Contrato local Rails + Broker

Fixtures exclusivas de teste. Não são uma forma de instalar os produtos nem de
conectar um número real. Nenhum segredo gerado deve ser versionado. Execução
observada e limitações: `docs/validation/2026-09-16-jrc-broker.md`.

## Ambiente exercitado

- JRC: HEAD 99df49d mais alterações J5, Ruby 3.4.4/Bundler 2.5.16.
- Broker: HEAD 71be532, código compilado com `npm run typecheck`, dependências da
  imagem local `jrc-whatsapp-broker:validation-20260915`, Node 24.19.0.
- Containers de teste nomeados `jrc-native-validation-*` e `jrc-contract-*`.
  Rails usa `jrc_broker_native_test`; Broker usa `jrc_contract_20260916`.
  As fixtures recusam execução fora do modo explicitamente sintético.
- Código do JRC copiado de `git archive` para `/workspace` e atualizado por
  overlay dos arquivos desta tarefa. Nenhum `.env` existente foi copiado.
- O Broker usa seu bootstrap normal de desenvolvimento, RLS e roles `jrc_app` /
  `jrc_auth`. O modo `NODE_ENV=test` da fábrica unitária omite rotas de runtime;
  por isso não serve como servidor para este contrato.

## Preparação

1. Criar PostgreSQL/Redis descartáveis e aplicar os schemas dos dois checkouts.
   Nunca reutilizar variáveis ou volumes de produção.
2. Criar diretório privado `.codex/contract/`. Gerar certificado TLS temporário
   para `broker.example.test`, `chatwoot.example.test`, `localhost`; confiar nele
   somente nos processos de teste (`SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`).
3. Criar rede Docker **interna** exclusiva. O laboratório usa 11.243.197.0/24
   somente dentro dessa rede, sem roteamento externo, para exercitar a política
   de endereços públicos sem desativar as proteções SSRF do Broker.
   Verificar sobreposições antes de criar redes em outra máquina.
4. O gateway `gateway.mjs` escuta TLS/443 e encaminha apenas para os dois serviços
   locais fixos. Recebe aliases `broker.example.test` / `chatwoot.example.test`.
   A rede de entrada separada publica apenas `127.0.0.1:18443:443` no host.
   Gateway e Broker montam o diretório privado em `/contract`.
5. `seed_rails.rb`, executado com `CONTRACT_TEST_ONLY=true` via Rails runner,
   cria contas/usuários aleatórios e grava `rails-fixture.json`. Copiar esse
   arquivo privado para `/contract` do Broker e para `.codex/contract` no host.
6. Iniciar Rails em test, com as três variáveis JRC e `FRONTEND_URL` descritas no
   guia de operação; a chave de cifra da fixture é Base64 de 32 caracteres `k`.
   Usar os assets compilados em `public/vite`, desativar auto build e instalar
   `http_test_runtime.rb` somente nos initializers do container HTTP descartável.
   Isso elimina a varredura de mtimes do recarregador em cada request.
7. Iniciar `broker.mjs` com `NODE_ENV=test`, `CONTRACT_TEST_ONLY=true`, roles/bancos
   acima, Redis de teste, segredos aleatórios de 32 bytes, origem pública
   `https://broker.example.test`, flags de destinos externos/controle habilitadas,
   `QR_WEBHOOK_ORIGIN` e `QR_WEBHOOK_SIGNING_KEY`. `EVOLUTION_BASE_URL` deve ser
   **http://127.0.0.1:3101**, a fixture local de telefone; nunca uma engine real.
   Montar os `dist/`, migrações e bootstrap SQL do Broker atual em `/app`.
8. O seed vincula a conta real de teste por TLS e emite uma chave limitada real.
   Copiar `broker-fixture.json` para `/contract` do Rails e para o diretório
   privado no host. As credenciais são dados de teste, não resultado público.

## Execução

Armar uma falha de callback criando `/contract/reject-next-callback` no diretório
compartilhado do gateway. Com o gateway recém-iniciado (contadores zerados):

```sh
CONTRACT_TEST_ONLY=true SSL_CERT_FILE=/tmp/contract.crt bundle exec rspec \
  spec/requests/api/v1/accounts/jrc_broker_contract_spec.rb
```

O teste usa requisições Rails autenticadas, Broker separado e callback HTTP para
Rails. WebMock libera somente o host sintético e não substitui suas respostas.
O gateway retém o POST por 150 ms por banco e compara PID/início da transação em
duas observações antes de encaminhá-lo. Isso identifica transação retida pelo
chamador durante HTTP sem confundir uma breve transação concorrente do worker.
A recuperação
exercita o job real e a assinatura real; o adaptador ActiveJob de teste adianta as
esperas. Redis/Sidekiq após reinício não são validados por esse teste.

Depois, no diretório `tests/playwright`, instalar pelo lockfile existente e rodar:

```sh
pnpm exec playwright test --config jrc-broker.config.ts
```

Perfil de navegador temporário, sem `.env` remoto, trace, vídeo ou screenshots
automáticos. Desktop e mobile usam apenas o servidor local. Só o navegador aceita
o certificado temporário por `ignoreHTTPSErrors`; Rails e Broker verificam TLS.

`gateway-stats.json` contém contadores sem payloads. `provider-stats.json` contabiliza
criações/pareamentos/envios da fixture. Nenhuma chamada vai a WhatsApp real.
Limpar o laboratório consiste em parar/remover somente containers, redes e volumes
identificados desta tarefa, após guardar evidências sanitizadas. Não apagar outros
containers ou redes para liberar espaço/endereços.
