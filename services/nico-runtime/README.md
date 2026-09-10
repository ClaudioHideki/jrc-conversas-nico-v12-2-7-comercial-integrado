# Runtime NICO

Serviço interno do JRC, atualizado em 09/09/2026. Inicializa `@elizaos/core` e `@elizaos/plugin-sql` 1.7.2 e chama `AgentRuntime.useModel`. O runtime planeja ações e gera respostas; Rails autoriza, executa e registra os resultados. Não há ferramenta genérica de shell, navegação ou acesso a banco oferecida ao modelo.

## Configuração

| Variável | Uso |
| --- | --- |
| `NICO_MODE` | Obrigatória: `fixture` ou `provider`. Atendimento delegado e voz exigem provider. |
| `NICO_SERVICE_TOKEN` | Segredo entre Rails e runtime, mínimo 32 caracteres; não vai ao navegador. |
| `NICO_ALLOWED_ACCOUNTS` | IDs permitidos. Em provider, exatamente uma conta por implantação. |
| `NICO_PGLITE_DATA_DIR` | Diretório persistente do adapter local. |
| `NICO_DATABASE_URL` | Alternativa PostgreSQL ao PGlite. |
| `NICO_PROVIDER_API_KEY` | Chave do provedor, somente no runtime. |
| `NICO_MODEL` | Modelo compatível com a saída JSON estruturada. |
| `NICO_PROVIDER_BASE_URL` | Base HTTPS; padrão `https://api.openai.com/v1/`. Não segue redirects. |
| `NICO_TRANSCRIPTION_MODEL` | Modelo de transcrição; padrão `gpt-4o-mini-transcribe`. |
| `NICO_MAX_CONCURRENCY` | Concorrência do runtime, padrão 3, limitada a 8. |
| `PORT` | Porta interna, padrão 3108. |

Confira os nomes e limites efetivos em `src/engine.ts` e `src/transcription.ts`. Rails recebe URL, token de serviço e modo. As configurações legadas da interface JRC AI não são importadas automaticamente. A instalação GoPure local usa provider para a conta 1; os segredos permanecem em `local/`, fora dos artefatos de validação.

## Contratos

Todos os POST exigem autenticação de serviço e escopo de conta permitido.

- `GET /health`: prontidão interna e modo; não comprova inferência externa.
- `POST /v1/analyze`: análise dos sete especialistas, com mensagens e fontes fornecidas por Rails. As referências de saída precisam existir na entrada.
- `POST /v1/operate`: `kind=operator` devolve resposta e uma ferramenta com argumentos limitados; `kind=customer` devolve resposta, resumo, indicação de encaminhamento ao humano e intenção de criar lead. O runtime não efetua os efeitos.
- `POST /v1/transcribe`: áudio em base64 canônico, MIME permitido, máximo 4 MB decodificados. Envia multipart ao endpoint de transcrição do provedor e retorna texto/uso. Não cria um comando operacional.

Históricos, corpos e respostas têm limites explícitos. O áudio capturado no navegador é de até 60 segundos, fica apenas em memória e exige envio posterior do texto revisado. O transporte do provedor tem timeout e propagação de cancelamento; cancelamento não garante estorno de processamento já iniciado. Logs não incluem chave, áudio, prompt ou corpo de resposta do provedor.

## Permissões e contabilização

Rails revalida conta, papel, acesso à conversa, ownership CRM e escopo das fontes. O atendimento do cliente recebe somente sua conversa pública, conhecimento público aprovado e catálogo permitido. Não consulta BEMTEVI ou Help Desk.

Cotas mensais usam um registro de inferência com reserva antes do envio. Operações de texto reservam uma margem conservadora baseada no tamanho do contexto; áudio e análises legadas usam a reserva padrão de 270 mil tokens. Sucesso converte reserva em uso informado. Falha com uso desconhecido mantém a reserva. O limite do provedor legado não governa este runtime.

Comandos e turnos de atendimento têm idempotência no JRC, travas, validade e versionamento. Resposta incerta de canal não é reenviada automaticamente. Mensagem já transmitida não pode ser desfeita por uma transação Rails.

## Compilar e validar

`npm ci`, `npm run build`, `npm test`. A suíte atual tem 15 testes de contratos, elizaOS/SQL, concorrência, cancelamento, HTTP e transcrição. Usa respostas controladas de provedor; as evidências com provedor real ficam em `../../docs/validation/nico-operational-e2e.json` e `nico-voice-e2e.json`.

`qa-synthetic-voice.ts` gera exclusivamente a frase fixa de homologação em `qa-voice.wav` e consome a API de voz; não faz parte da experiência do produto. O arquivo permite repetir o teste sem usar o microfone de uma pessoa.

Consulte `../../docs/NICO-ASSISTENTE-OPERACIONAL-20260909.md` para uso, cobertura, limites e inicialização do sistema completo.
