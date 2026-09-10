# NICO com OpenAI — configuração local

Configuração de 08/09/2026. A chave fica somente em `local/nico-provider.env`, ignorado pelo Git. Não incluir esse arquivo em ZIPs ou outros artefatos de transferência. O pacote de transferência de 07/09/2026 permanece sem chave e em modo de simulação.

O modelo configurado é `gpt-4.1-mini`, usando o transporte Chat Completions já implementado no plugin do runtime elizaOS. A conta permitida neste runtime é somente a conta 1 (GoPure Homologação).

## Iniciar com provedor real

Na raiz do projeto:

```powershell
pwsh -NoProfile -File scripts/nico-provider-start.ps1
```

O script aplica `docker-compose.nico-local.yml` e o complemento `docker-compose.nico-provider.yml`. Somente o runtime recebe a variável da chave do provedor e a rede de saída necessária; Rails continua autenticando o atendente, preparando o contexto e controlando a fila e o consumo. O elizaOS usa essa mesma configuração: não é necessário cadastrar uma segunda chave para ele.

Não use somente o Compose de simulação para reiniciar este modo, pois isso troca os serviços novamente para fixture. Para voltar intencionalmente à simulação:

```powershell
docker compose -f docker-compose.nico-local.yml up -d --wait web worker runtime gateway
```

## Usar e trocar a chave

Abra a conversa sintética da conta 1, clique em Copiloto JRC e solicite uma análise. Cada nova análise em modo provider pode consumir créditos OpenAI, com até 2.000 tokens de resposta por chamada e timeout de 45 segundos no transporte. As quotas do backend continuam ativas.

Para trocar a chave, edite `NICO_PROVIDER_API_KEY` no arquivo local e execute novamente o script de início com provedor real. Chaves compartilhadas em chat devem ser revogadas e substituídas. Não cole a nova chave em mensagens.

O NICO sugere conteúdo para revisão do atendente e pode preparar atividade CRM que exige aprovação humana. Esta configuração não implementa a Ana, os demais especialistas ou resposta automática a WhatsApp/Instagram.

## Evidências

Teste integrado concluído em 08/09/2026: análise 7 na conta 1, modelo `gpt-4.1-mini`, 375 tokens de entrada e 128 de saída (503 total). A resposta citou a conversa e o lead autorizado; nenhuma mensagem pública foi criada. Esses 503 tokens correspondem à análise aprovada, não ao consumo total dos diagnósticos anteriores.

A primeira resposta real não cumpriu o contrato e foi rejeitada. O transporte passou a solicitar `json_schema` estrito, mantendo as validações de tipos, tamanhos e referências locais. A regressão falhou antes da correção e os nove testes do runtime passaram depois. A compilação foi concluída e a análise real acima passou pelo fluxo Rails/Sidekiq/elizaOS/OpenAI.

A validação visual também passou: sugestão real exibida no Copiloto, ausência do aviso de simulação nessa análise e criação de atividade CRM somente após a caixa de autorização humana, sem erros JavaScript. Evidência: `docs/validation/nico-provider-ui-20260908.json` e capturas `nico-provider-analise.png`/`nico-provider-crm.png`.

O preflight OpenAI em `docs/validation/openai-preflight-20260908.json` registra somente status, modelo e consumo, sem credenciais. O resultado do teste integrado, quando concluído, fica em `docs/validation/nico-provider-e2e-20260908.json`. Capturas do teste visual real são identificadas como `nico-provider-*.png`.

Referência: https://developers.openai.com/api/docs/models/gpt-4.1-mini
