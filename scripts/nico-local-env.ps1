$ErrorActionPreference = 'Stop'
$nicoProject = Split-Path -Parent $PSScriptRoot
$nicoLocal = Join-Path $nicoProject 'local'
$nicoEnvFile = Join-Path $nicoLocal 'nico.env'
New-Item -ItemType Directory -Path $nicoLocal -Force | Out-Null
if (Test-Path -LiteralPath $nicoEnvFile) {
  Write-Output 'Configuração local existente preservada.'
  exit 0
}
function New-NicoSecret {
  $nicoBytes = New-Object byte[] 32
  [Security.Cryptography.RandomNumberGenerator]::Fill($nicoBytes)
  return [Convert]::ToHexString($nicoBytes).ToLowerInvariant()
}
$nicoValues = @(
  'SECRET_KEY_BASE=' + (New-NicoSecret)
  'POSTGRES_PASSWORD=' + (New-NicoSecret)
  'NICO_SERVICE_TOKEN=' + (New-NicoSecret)
  'NICO_LOCAL_PASSWORD=Jrc!' + (New-NicoSecret).Substring(0, 20)
  'NICO_ALLOWED_ACCOUNTS=1,2'
)
Set-Content -LiteralPath $nicoEnvFile -Value $nicoValues -Encoding utf8
Write-Output 'Configuração criada em local/nico.env. Credenciais não exibidas.'
