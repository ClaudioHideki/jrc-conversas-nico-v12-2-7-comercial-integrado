#requires -Version 7.2
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  & docker compose -p jrc-nico-transfer -f docker-compose.nico-local.yml -f docker-compose.nico-transfer.yml up -d --wait web worker runtime gateway
  if ($LASTEXITCODE -ne 0) { throw 'Não foi possível iniciar o ambiente transferido.' }
  Write-Output 'http://localhost:3107'
} finally { Pop-Location }
