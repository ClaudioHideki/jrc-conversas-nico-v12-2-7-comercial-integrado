#requires -Version 7.2
$ErrorActionPreference = 'Stop'
# Códigos nativos são tratados abaixo, inclusive a imagem ainda inexistente.
$PSNativeCommandUseErrorActionPreference = $false
Set-StrictMode -Version Latest

function Invoke-NicoDocker {
  param([Parameter(Mandatory)][string[]] $DockerArguments)
  & docker @DockerArguments
  if ($LASTEXITCODE -ne 0) { throw "Docker falhou (código $LASTEXITCODE). Inicialização interrompida." }
}

$nicoProject = Split-Path -Parent $PSScriptRoot
Push-Location $nicoProject
try {
  & (Join-Path $PSScriptRoot 'nico-local-env.ps1')
  Invoke-NicoDocker @('info', '--format', '{{.ServerVersion}}')
  & docker image inspect jrc-nico-test:local --format '{{.Id}}' 2>$null
  if ($LASTEXITCODE -ne 0) {
    Invoke-NicoDocker @('compose', '-f', 'docker-compose.nico-test.yml', 'build', 'app')
  }

  # Instalações usam a rede de teste e os volumes Linux compartilhados.
  Invoke-NicoDocker @('compose', '-f', 'docker-compose.nico-test.yml', 'run', '--rm', '--no-deps', '-e', 'HUSKY=0', 'app', 'pnpm', 'install', '--frozen-lockfile', '--store-dir', '/app/.pnpm-store', '--network-concurrency=2', '--child-concurrency=1')
  & (Join-Path $PSScriptRoot 'nico-local-frontend.ps1')
  Invoke-NicoDocker @('compose', '-f', 'docker-compose.nico-test.yml', 'run', '--rm', '--no-deps', 'runtime', 'npm', 'ci')
  Invoke-NicoDocker @('compose', '-f', 'docker-compose.nico-test.yml', 'run', '--rm', '--no-deps', 'runtime', 'npm', 'run', 'build')
  Invoke-NicoDocker @('compose', '-f', 'docker-compose.nico-local.yml', 'up', '-d', '--wait', 'postgres', 'redis')

  $nicoCountOutput = Invoke-NicoDocker @('compose', '-f', 'docker-compose.nico-local.yml', 'exec', '-T', 'postgres', 'psql', '-U', 'postgres', '-d', 'jrc_nico_homologacao', '-At', '-v', 'ON_ERROR_STOP=1', '-c', "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';")
  $nicoTableCount = 0
  if (-not [int]::TryParse(($nicoCountOutput -join '').Trim(), [ref] $nicoTableCount) -or $nicoTableCount -lt 0) {
    throw 'Não foi possível determinar se o banco está vazio. Nenhum schema será carregado.'
  }
  $nicoDatabaseTask = if ($nicoTableCount -eq 0) { 'db:schema:load' } else { 'db:migrate' }
  Invoke-NicoDocker @('compose', '-f', 'docker-compose.nico-local.yml', 'run', '--rm', '--no-deps', 'web', 'bundle', 'exec', 'rails', $nicoDatabaseTask)
  Invoke-NicoDocker @('compose', '-f', 'docker-compose.nico-local.yml', 'run', '--rm', '--no-deps', 'web', 'bundle', 'exec', 'rails', 'runner', 'scripts/nico-local-seed.rb')
  Invoke-NicoDocker @('compose', '-f', 'docker-compose.nico-local.yml', 'up', '-d', '--wait', '--force-recreate', 'web', 'worker', 'runtime', 'gateway')
  Write-Output 'Serviços iniciados: http://localhost:3107. Credenciais em local/nico.env; consulte docs/NICO-HOMOLOGACAO-LOCAL.md para validar a interface.'
} finally {
  Pop-Location
}
