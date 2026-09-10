#requires -Version 7.2
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
Set-StrictMode -Version Latest

function Invoke-NicoDocker {
  param([Parameter(Mandatory)][string[]] $DockerArguments)
  & docker @DockerArguments
  if ($LASTEXITCODE -ne 0) { throw "Docker falhou (código $LASTEXITCODE). Backup interrompido; confira eventual arquivo parcial." }
}

$nicoProject = Split-Path -Parent $PSScriptRoot
$nicoEnv = Join-Path $nicoProject 'local/nico.env'
if (-not (Test-Path -LiteralPath $nicoEnv -PathType Leaf)) { throw 'Configuração ausente. Execute scripts/nico-local-start.ps1 primeiro.' }
$nicoBackupDirectory = Join-Path $nicoProject 'local/backups'
New-Item -ItemType Directory -Path $nicoBackupDirectory -Force | Out-Null
$nicoStamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$nicoFilename = "nico-$nicoStamp-$([Guid]::NewGuid().ToString('N').Substring(0, 8)).sql"
$nicoBackup = Join-Path $nicoBackupDirectory $nicoFilename

Push-Location $nicoProject
try {
  Invoke-NicoDocker @('compose', '-f', 'docker-compose.nico-local.yml', 'exec', '-T', 'postgres', 'pg_isready', '-U', 'postgres', '-d', 'jrc_nico_homologacao')
  # pg_dump grava UTF-8 diretamente no bind. A senha fica no ambiente do container.
  Invoke-NicoDocker @('run', '--rm', '--network', 'jrc-nico-local_default', '--env-file', $nicoEnv, '--mount', "type=bind,source=$nicoBackupDirectory,target=/backup", 'pgvector/pgvector:pg16', 'sh', '-c', 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec pg_dump "$@"', 'sh', '--host=postgres', '--username=postgres', '--dbname=jrc_nico_homologacao', '--format=plain', '--encoding=UTF8', '--no-owner', '--no-privileges', "--file=/backup/$nicoFilename")
  if (-not (Test-Path -LiteralPath $nicoBackup -PathType Leaf) -or (Get-Item -LiteralPath $nicoBackup).Length -eq 0) {
    throw 'pg_dump não produziu um arquivo válido. Backup não confirmado.'
  }
  Write-Output "Backup PostgreSQL concluído: $nicoBackup"
} finally {
  Pop-Location
}
