#requires -Version 7.2
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
Set-StrictMode -Version Latest

function Invoke-FrontendDocker {
  param([Parameter(Mandatory)][string[]] $DockerArguments)
  & docker @DockerArguments
  if ($LASTEXITCODE -ne 0) { throw "Compilação local interrompida: Docker retornou $LASTEXITCODE." }
}

$nicoProject = Split-Path -Parent $PSScriptRoot
$nicoBuildId = [Guid]::NewGuid().ToString('N')
$nicoArchive = Join-Path $nicoProject "local/frontend-$nicoBuildId.tar"
$nicoLog = Join-Path $nicoProject "local/frontend-$nicoBuildId.log"
Push-Location $nicoProject
try {
  New-Item -ItemType Directory -Path local -Force | Out-Null
  & tar -cf $nicoArchive --exclude=.git --exclude=local --exclude=node_modules --exclude=.pnpm-store --exclude=tmp --exclude=log --exclude=storage --exclude=.env --exclude=.env.* --exclude=services --exclude=public/vite-dev --exclude=public/vite-test --exclude=vendor/bundle .
  if ($LASTEXITCODE -ne 0) { throw 'Não foi possível preparar os fontes para compilação.' }
  $nicoContainer = (Invoke-FrontendDocker @('create', '--name', "jrc-nico-frontend-$nicoBuildId", '--memory', '3100m', '--memory-swap', '5g', '--volume', '/app', '--mount', 'type=volume,source=jrc-gopure_node_modules,target=/app/node_modules', '--workdir', '/app', '-e', 'NODE_OPTIONS=--max-old-space-size=2816', '-e', 'RAILS_ENV=development', '-e', 'NODE_ENV=production', 'jrc-nico-test:local', 'sh', '-c', 'tar -xf /tmp/source.tar -C /app && pnpm exec vite build --mode development')).Trim()
  if ($nicoContainer -notmatch '^[a-f0-9]{64}$') { throw 'Identificador inesperado de container.' }
  Invoke-FrontendDocker @('cp', $nicoArchive, "${nicoContainer}:/tmp/source.tar")
  Write-Output "Compilando em volume Linux. Acompanhe o log em $nicoLog"
  & docker start -a $nicoContainer *> $nicoLog
  if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $nicoLog -Tail 30
    throw "Build falhou. Container $nicoContainer preservado para diagnóstico."
  }
  Invoke-FrontendDocker @('cp', "${nicoContainer}:/app/public/vite-dev", 'public')
  if (-not (Test-Path 'public/vite-dev/.vite/manifest.json')) { throw 'Manifesto da interface não foi copiado.' }
  # Remove somente o container criado acima e seu volume anônimo; o volume nomeado de dependências permanece.
  Invoke-FrontendDocker @('rm', '-v', $nicoContainer)
  Remove-Item -LiteralPath $nicoArchive
  Write-Output 'Interface compilada e disponível em public/vite-dev.'
} finally {
  Pop-Location
}

