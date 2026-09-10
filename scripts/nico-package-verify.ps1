#requires -Version 7.2
$ErrorActionPreference='Stop'
function D([string[]]$Arguments) { & docker @Arguments; if($LASTEXITCODE -ne 0){throw 'Validação falhou. Consulte os testes indicados.'} }
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  $test=@('compose','-p','jrc-nico-test','-f','docker-compose.nico-test.yml')
  D ($test+@('up','-d','--wait','postgres','redis'))
  D ($test+@('run','--rm','app','bundle','exec','rails','db:prepare'))
  $specs=@(Get-ChildItem spec/requests/jrc_nico_*_spec.rb | ForEach-Object { 'spec/requests/'+$_.Name })
  D ($test+@('run','--rm','app','bundle','exec','ruby','scripts/nico-specs.rb')+$specs+@('spec/services/jrc_nico','spec/jobs/jrc_nico','spec/services/jrc_ai/nico_readiness_spec.rb','spec/services/conversations/assignment_service_spec.rb','spec/builders/messages/message_builder_spec.rb','spec/jobs/send_reply_job_spec.rb'))
  $run=@('compose','-p','jrc-gopure','-f','docker-compose.nico-local.yml','-f','docker-compose.nico-package.yml','-f','docker-compose.nico-provider.yml')
  D ($run+@('exec','-T','web','pnpm','exec','vitest','run','--config','vitest.nico.config.ts'))
  D ($run+@('exec','-T','runtime','npm','test'))
  Write-Output 'Testes automatizados concluídos. Valide a interface, comandos e integrações configuradas conforme docs/NICO-ASSISTENTE-OPERACIONAL-20260909.md.'
} finally {Pop-Location}
