#requires -Version 7.2
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  & docker compose -f docker-compose.nico-local.yml -f docker-compose.nico-provider.yml up -d --wait web worker runtime gateway
  if ($LASTEXITCODE -ne 0) { throw 'Não foi possível iniciar o NICO com provedor real.' }
  Write-Output 'JRC local com NICO/OpenAI: http://localhost:3107. Conta autorizada: 1. Cada análise pode consumir créditos da API.'
} finally { Pop-Location }
