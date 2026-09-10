# Homologação local do NICO

Atualização em 08/09/2026: o ambiente em execução também foi configurado e testado com OpenAI real. Para manter esse modo, use [NICO-PROVEDOR-REAL-LOCAL.md](NICO-PROVEDOR-REAL-LOCAL.md). Os comandos abaixo continuam sendo os procedimentos específicos de simulação e voltam o runtime para fixture.

Este ambiente usa dados sintéticos e `NICO_MODE=fixture` explicitamente. O runtime executa o contrato local sem validar um provedor de IA real. A inicialização dos containers não comprova os fluxos da interface: a homologação visual e de ponta a ponta deve ser registrada separadamente.

## Preparar e iniciar

Requisitos: Windows com PowerShell 7.2 ou superior (`pwsh`), Docker Desktop em modo Linux, Docker Compose com suporte a `up --wait` e espaço para imagens, gems e dependências Node. Execute na raiz do repositório:

```powershell
pwsh -File scripts/nico-local-start.ps1
```

O script preserva `local/nico.env` existente; na primeira execução usa `scripts/nico-local-env.ps1` para gerar os segredos sem imprimi-los. Constrói `jrc-nico-test:local` somente quando a imagem falta, instala dependências pelos lockfiles nos volumes Linux de `docker-compose.nico-test.yml`, compila o runtime e a interface antes de iniciar PostgreSQL e Redis locais. O frontend usa build do Vite com NODE_ENV=production e --mode development para gerar os arquivos no diretório da homologação. Não mantém um servidor Vite de desenvolvimento: este encontrou ENOMEM durante a varredura de estilos no Windows/Docker. Após alterar Vue/JS, execute o build novamente e reinicie web para recarregar o manifesto dos arquivos. O script completo recria os serviços de aplicação ao final. O backend continua Rails development, exclusivo para dados sintéticos, com recarga automática desativada por JRC_NICO_LOCAL_STATIC=true. Reinicie web e worker após alterar Ruby. O script nico-local-frontend.ps1 compila um snapshot sem credenciais em volume Linux, com heap de 2816 MiB e limite de container de 3100 MiB. O log fica em local/frontend-*.log. Reserve memória para essa etapa e mantenha os serviços de aplicação parados durante a compilação. Na máquina de 8 GiB, foi necessário parar temporariamente outros ambientes Docker. Tidewave não é carregado quando JRC_NICO_LOCAL_STATIC=true, pois esse depurador exige recarga automática. O pnpm usa `--network-concurrency=2 --child-concurrency=1` para reduzir o consumo de memória após o ENOMEM observado na preparação inicial. Instalações e downloads precisam de internet e podem demorar. Se o Dockerfile ou Gemfile mudar, reconstrua explicitamente antes de iniciar:

```powershell
docker compose -f docker-compose.nico-test.yml build app
```

O banco dedicado é `jrc_nico_homologacao`. O script consulta a quantidade de tabelas no schema `public`: somente com zero tabelas executa `db:schema:load`; em banco existente executa `db:migrate`. Depois executa `scripts/nico-local-seed.rb` e sobe `web`, `worker`, `runtime` e `gateway`. Qualquer comando Docker com erro interrompe a sequência. Corrija a causa e execute novamente; o script não apaga volumes nem recria um banco preenchido. Em atualizações de um ambiente já usado, faça backup e pare os serviços de aplicação antes de alterar schema/dependências:

```powershell
pwsh -File scripts/nico-local-backup.ps1
docker compose -f docker-compose.nico-local.yml stop gateway web worker runtime
pwsh -File scripts/nico-local-start.ps1
```

A aplicação fica em [http://localhost:3107](http://localhost:3107), com a interface pré-compilada em `public/vite-dev`. As duas contas criadas pelo seed são:

| Conta | Administrador |
| --- | --- |
| GoPure Homologação (ID 1) | `admin@gopure.test` |
| Conta Isolada Homologação (ID 2) | `admin@isolada.test` |

O usuário `operator@gopure.test` é atendente (`agent`) da GoPure, vinculado ao canal sintético da conta 1, sem permissão de CRM. Use-o para conferir as restrições do NICO e de campanhas para usuários não administradores. Ele usa a mesma senha local quando criado pelo seed.

A senha dos usuários novos é o valor de `NICO_LOCAL_PASSWORD` em `local/nico.env`. Abra esse arquivo localmente; não publique seu conteúdo. O seed preserva usuários existentes e não redefine suas senhas. Ele exige os IDs 1 e 2 no banco dedicado; se recusar um banco incompatível, investigue-o sem apagar dados. Cada conta recebe um canal API sintético, contato, conversa, lead e documento de conhecimento aprovado para o exercício local. Não há credenciais de WhatsApp real neste roteiro.

`docker-compose.nico-local.yml` mantém aplicação, worker, PostgreSQL, Redis e runtime apenas na rede Docker `internal: true`, sem saída normal para a internet. O gateway Node participa dessa rede e da rede `ingress`, publicando somente `127.0.0.1:3107`. Ele não recebe `local/nico.env` nem credenciais de aplicação e encaminha HTTP/WebSocket para destino fixo (`web:3000`). Essa passagem permite acesso pelo navegador apesar da restrição de publicação de portas observada na rede interna. PostgreSQL, Redis e runtime não publicam portas no host. A preparação de dependências usa a rede separada do compose de testes, que permite downloads. Não use a ausência de chamadas externas em fixture como evidência de integração com um provedor.

## Reabrir o ambiente já preparado

Quando dependências, código e banco não mudaram, não é preciso recompilar. Execute na raiz do projeto:

```powershell
docker compose -f docker-compose.nico-local.yml up -d --wait web worker runtime gateway
```

Acesse http://localhost:3107/app/login. Para validar NICO, abra a conversa do Cliente Sintético 1, clique no botão flutuante do Copiloto JRC e escreva no campo de análise. A simulação local não gera respostas de um modelo externo. As análises e propostas ficam registradas no banco dedicado.
## Onde estão o `.env` e as credenciais?

A cópia de desenvolvimento não usa `.env` na raiz para esta homologação. O Compose carrega explicitamente `local/nico.env` pelo campo `env_file`. A senha de login é `NICO_LOCAL_PASSWORD`; `POSTGRES_PASSWORD` autentica o banco, `SECRET_KEY_BASE` protege a aplicação e `NICO_SERVICE_TOKEN` autentica a comunicação interna com NICO. Esses valores têm funções diferentes e não devem ser usados como chave OpenAI.

A configuração original recebida no ZIP permanece na pasta original extraída. Ela não foi ativada neste ambiente. Uma chave cadastrada pela tela do JRC pode estar no banco original; sua ausência em um `.env` não prova que nunca foi configurada.

O arquivo local/nico-provider.env foi preparado, vazio, para receber NICO_PROVIDER_API_KEY e NICO_MODEL sem expor valores no chat. Ele não é carregado pelo Compose de simulação. Para inferência real, o runtime exige `NICO_PROVIDER_API_KEY`, `NICO_MODEL` e modo `provider`, além de saída de rede autorizada e uma única conta por runtime. Apenas inserir uma chave no arquivo local não ativa o provedor: esta configuração mantém `fixture` e rede interna. Consulte `services/nico-runtime/README.md`. WhatsApp e Instagram usam as integrações de canais do JRC, com suas próprias credenciais; a chave OpenAI serve para gerar as análises.
## Conferência operacional e visual

```powershell
docker compose -f docker-compose.nico-local.yml ps
docker compose -f docker-compose.nico-local.yml logs --tail 100 gateway web worker runtime
```

Entre com cada administrador, confirme o acesso à conversa sintética e ao NICO, e registre as respostas obtidas em fixture. Verifique que os dados da outra conta não aparecem, inclusive após navegação entre contas. Para campanhas, confira consentimento positivo, revisão e aprovação antes de disparo; execute cenários de envio apenas com canais/provedores simulados em testes. Estes passos são um roteiro a executar, não uma declaração de aprovação de E2E.

Para parar sem remover dados:

```powershell
docker compose -f docker-compose.nico-local.yml stop
```

## Backup PostgreSQL

Com PostgreSQL local em execução:

```powershell
pwsh -File scripts/nico-local-backup.ps1
```

O arquivo SQL UTF-8 recebe nome único com horário UTC em `local/backups/`. Um container temporário executa `pg_dump` e grava pelo bind mount, sem redirecionamento binário do PowerShell e sem imprimir senhas. Não sobrescreve backups anteriores. Se ocorrer erro, um arquivo parcial pode permanecer; não o trate como backup confirmado.

Este backup cobre somente PostgreSQL. Não inclui arquivos do Active Storage, Redis, o volume PGlite `runtime_data` ou `local/nico.env`. Preserve esses dados separadamente se precisar recuperar todo o ambiente. O SQL pode conter dados e credenciais persistidos pela aplicação; mantenha-o local e protegido. A pasta `local/` está ignorada pelo Git.

## Restaurar manualmente em um banco novo

Não restaure sobre `jrc_nico_homologacao`. Escolha um nome novo e substitua o arquivo abaixo por um backup concluído. Execute na raiz do repositório, em PowerShell 7.2+. `createdb` deve terminar com código zero; se o banco já existir, pare e escolha outro nome. Não use `dropdb`, `--clean` ou remoção de volumes.

```powershell
$nicoRestoreDatabase = 'jrc_nico_restore_20260907'
$nicoRestoreFile = 'nico-COLOQUE-O-NOME-DO-BACKUP.sql'
$nicoRestoreDirectory = (Resolve-Path 'local/backups').Path
if (-not (Test-Path -LiteralPath (Join-Path $nicoRestoreDirectory $nicoRestoreFile) -PathType Leaf)) { throw 'Backup não encontrado' }
docker compose -f docker-compose.nico-local.yml exec -T postgres createdb -U postgres $nicoRestoreDatabase
if ($LASTEXITCODE -ne 0) { throw 'Não foi criado um banco novo; restauração interrompida' }
docker run --rm --network jrc-nico-local_default --env-file local/nico.env --mount "type=bind,source=$nicoRestoreDirectory,target=/backup,readonly" pgvector/pgvector:pg16 sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql "$@"' sh --host=postgres --username=postgres "--dbname=$nicoRestoreDatabase" --set=ON_ERROR_STOP=1 "--file=/backup/$nicoRestoreFile"
if ($LASTEXITCODE -ne 0) { throw 'Restauração falhou; o banco novo pode estar parcialmente preenchido' }
docker compose -f docker-compose.nico-local.yml exec -T postgres psql -U postgres -d $nicoRestoreDatabase -c 'SELECT count(*) AS public_tables FROM pg_tables WHERE schemaname = ''public'';'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao conferir o banco restaurado' }
```

Inspecione os dados restaurados antes de qualquer mudança de configuração. Esse procedimento não aponta a aplicação para o banco restaurado e não executa o seed nele. Uma restauração testada deve ser registrada separadamente do simples sucesso de `pg_dump`.

