#requires -Version 7.2
param([switch]$SkipBuild)
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
function D([string[]]$Arguments) { & docker @Arguments; if($LASTEXITCODE -ne 0){throw "Docker falhou na etapa $($Arguments[0]). Consulte a saída acima."} }
$project=Split-Path -Parent $PSScriptRoot
$package=Split-Path -Parent $project
$compose=@('compose','-p','jrc-gopure','-f','docker-compose.nico-local.yml','-f','docker-compose.nico-package.yml','-f','docker-compose.nico-provider.yml')
Push-Location $project
try {
  foreach($file in @('local/nico.env','local/nico-provider.env')) {if(!(Test-Path $file)){throw 'Execute Configurar-Credenciais.mjs na raiz do pacote primeiro.'}}
  D @('info','--format','{{.OSType}}/{{.Architecture}}')
  if(!$SkipBuild) {
    D @('build','-t','jrc-nico-test:local','-f','docker/nico-test.Dockerfile','.')
    D ($compose+@('run','--rm','--no-deps','-e','HUSKY=0','web','pnpm','install','--frozen-lockfile','--network-concurrency=2','--child-concurrency=1'))
    & (Join-Path $PSScriptRoot 'nico-local-frontend.ps1')
    D ($compose+@('run','--rm','--no-deps','runtime','npm','ci'))
    D ($compose+@('run','--rm','--no-deps','runtime','npm','run','build'))
    D ($compose+@('run','--rm','--no-deps','runtime','npm','test'))
  }
  if(!(Test-Path 'public/vite-dev/.vite/manifest.json')){throw 'Interface não compilada. Execute novamente sem SkipBuild.'}
  D ($compose+@('up','-d','--wait','postgres','redis'))
  $count=& docker @compose exec -T postgres psql -U postgres -d jrc_nico_homologacao -At -c "SELECT count(*) FROM pg_tables WHERE schemaname='public';"
  if($LASTEXITCODE -ne 0){throw 'Não foi possível verificar o banco.'}
  if(($count -join '').Trim() -eq '0') {
    $snapshot=Join-Path $package 'transferencia/database-20260907.sql'
    if(Test-Path $snapshot) {
      D ($compose+@('cp',$snapshot,'postgres:/tmp/jrc-snapshot.sql'))
      D ($compose+@('exec','-T','postgres','psql','-U','postgres','-d','jrc_nico_homologacao','-v','ON_ERROR_STOP=1','--single-transaction','-f','/tmp/jrc-snapshot.sql'))
    } else { D ($compose+@('run','--rm','--no-deps','web','bundle','exec','rails','db:schema:load')) }
  }
  D ($compose+@('run','--rm','--no-deps','web','bundle','exec','rails','db:migrate'))
  D ($compose+@('run','--rm','--no-deps','web','bundle','exec','rails','runner','scripts/nico-local-seed.rb'))
  D ($compose+@('up','-d','--wait','--force-recreate','runtime','web','worker','gateway'))
  Write-Output 'GoPure: http://localhost:3107 — admin@gopure.test. Senha em local/nico.env. NICO operacional sem consultas ERP.'
} finally {Pop-Location}


