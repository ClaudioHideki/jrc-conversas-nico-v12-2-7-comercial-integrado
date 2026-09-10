#requires -Version 7.2
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
Set-StrictMode -Version Latest
function D([string[]] $Arguments) {
  & docker @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Docker falhou: $($Arguments[0]). Restauração interrompida." }
}
$project = Split-Path -Parent $PSScriptRoot
$package = Split-Path -Parent $project
$payload = Join-Path $package 'transferencia'
$compose = @('compose', '-p', 'jrc-nico-transfer', '-f', 'docker-compose.nico-local.yml', '-f', 'docker-compose.nico-transfer.yml')
Push-Location $project
try {
  if (Test-Path (Join-Path $payload 'restaurado.txt')) { throw 'Este pacote já foi restaurado. Use nico-transfer-start.ps1.' }
  D @('info', '--format', '{{.OSType}}/{{.Architecture}}')
  $platform = & docker info --format '{{.OSType}}/{{.Architecture}}'
  if ($platform -notmatch '^linux/(x86_64|amd64)$') { throw 'Este pacote exige Docker com containers Linux x86_64/amd64.' }
  $volumes = @('jrc-nico-transfer_node_modules', 'jrc-nico-transfer_runtime_modules', 'jrc-nico-transfer_runtime_data', 'jrc-nico-transfer_redis_data', 'jrc-nico-transfer_postgres_data')
  $existing = & docker volume ls --format '{{.Name}}'
  if ($LASTEXITCODE -ne 0) { throw 'Não foi possível listar os volumes.' }
  foreach ($volume in $volumes) { if ($volume -in $existing) { throw "O volume $volume já existe. Nenhum dado será sobrescrito. Use uma máquina/ambiente Docker vazio para a primeira restauração." } }
  $listener = Get-NetTCPConnection -LocalPort 3107 -State Listen -ErrorAction SilentlyContinue
  if ($listener) { throw 'A porta 3107 já está em uso. Encerre o ambiente anterior antes da transferência.' }
  $manifest = Get-Content (Join-Path $package 'SHA256.json') -Raw | ConvertFrom-Json
  foreach ($item in $manifest) {
    $file = Join-Path $package $item.path
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.sha256) { throw "Arquivo inválido: $($item.path)" }
  }
  D @('load', '-i', (Join-Path $payload 'docker-images.tar.gz'))
  foreach ($name in @('node_modules', 'runtime_modules', 'runtime_data', 'redis_data')) {
    D @('volume', 'create', "jrc-nico-transfer_$name")
    D @('run', '--rm', '--mount', "type=volume,source=jrc-nico-transfer_$name,target=/restore", '--mount', "type=bind,source=$payload,target=/backup,readonly", 'node:24.13.0-bookworm-slim', 'tar', '-xzf', "/backup/$name.tar.gz", '-C', '/restore')
  }
  D ($compose + @('up', '-d', '--wait', 'postgres', 'redis'))
  D ($compose + @('cp', (Join-Path $payload 'database.sql'), 'postgres:/tmp/nico-transfer.sql'))
  D ($compose + @('exec', '-T', 'postgres', 'psql', '-U', 'postgres', '-d', 'jrc_nico_homologacao', '-v', 'ON_ERROR_STOP=1', '-f', '/tmp/nico-transfer.sql'))
  D ($compose + @('up', '-d', '--wait', 'web', 'worker', 'runtime', 'gateway'))
  Set-Content -LiteralPath (Join-Path $payload 'restaurado.txt') -Value ([DateTime]::UtcNow.ToString('o'))
  Write-Output 'JRC disponível em http://localhost:3107. Consulte LEIA-ME.md para o login e os limites da homologação.'
} finally { Pop-Location }
