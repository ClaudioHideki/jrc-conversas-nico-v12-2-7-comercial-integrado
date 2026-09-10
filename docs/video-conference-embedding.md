# Incorporação do JRC Meet no JRC Conversas

## Diagnóstico do erro 419

O JRC Conversas usa a URL exata cadastrada pelo Super Admin em um `iframe`. O
JRC Meet responde como uma aplicação Laravel e, na verificação de 13/08/2026,
os cookies de sessão e CSRF foram emitidos com `SameSite=Lax` (ou sem o atributo,
que navegadores atuais tratam como `Lax`) e sem `Secure`.

Esse formato funciona quando o JRC Meet é aberto diretamente em uma aba, mas
não é compatível com um iframe em um site diferente. Nesse contexto, os cookies
podem não acompanhar as requisições do fluxo da sala. Sem a sessão correspondente,
o token CSRF não pode ser validado e o Laravel responde com `419 PAGE EXPIRED`.

A correção precisa ser aplicada no servidor do JRC Meet. Não é possível corrigir
cookies, sessão ou CSRF de outro domínio pelo frontend do JRC Conversas.

## Configuração a revisar no JRC Meet

No ambiente Laravel que atende as URLs de sala, revisar `config/session.php` e
as variáveis equivalentes:

```dotenv
SESSION_SECURE_COOKIE=true
SESSION_SAME_SITE=none
```

Depois da alteração:

1. servir todas as páginas e recursos da sala por HTTPS;
2. limpar o cache de configuração do Laravel e reconstruí-lo conforme o processo
   de implantação do JRC Meet;
3. confirmar que tanto o cookie de sessão quanto `XSRF-TOKEN` retornam com
   `SameSite=None; Secure`;
4. verificar se navegador ou política corporativa bloqueia cookies de terceiros;
5. manter a proteção CSRF ativa e confirmar que formulários/requisições enviam o
   token correspondente à mesma sessão;
6. revisar redirecionamentos entre `jrcmeet2.jrcpabx.com.br` e
   `meet.jrcpabx.com.br`, evitando trocar a sessão entre hosts sem uma estratégia
   de domínio de cookie deliberada e segura;
7. permitir incorporação somente pelos endereços conhecidos do JRC Conversas.

Exemplo de política no JRC Meet, substituindo os endereços pelos domínios reais:

```http
Content-Security-Policy: frame-ancestors 'self' https://conversas.exemplo.com
```

Não usar `frame-ancestors *`, não remover CSRF e não criar proxy de autenticação
no JRC Conversas. Se `X-Frame-Options` estiver presente nas respostas das salas,
ele também precisa ser compatível com a política de incorporação; prefira controlar
os destinos permitidos com `frame-ancestors`.

Em testes locais por `http://localhost`, o comportamento de cookies pode diferir
da produção. A validação final deve ser feita com o JRC Conversas em HTTPS no seu
domínio definitivo.

## Encerramento da reunião

O JRC Conversas não pode ler o DOM ou detectar a navegação interna de um iframe
de outro domínio. O retorno automático só deve ser implementado se o JRC Meet
publicar um contrato oficial de `window.postMessage` para o encerramento da sala,
com origem, nome do evento e formato da mensagem documentados. Nesse caso, o
listener deve validar rigorosamente `event.origin` e o payload.

Enquanto esse contrato não existir, o botão **Voltar** é o mecanismo confiável.
Ele fecha o iframe e restaura a tela inicial da Vídeo Conferência, mantendo as
URLs e senhas carregadas. O botão **Abrir em nova aba** permanece como fallback
para o erro 419 ou qualquer bloqueio de incorporação.
