# Conta de teste e vínculo nativo HML

O usuário autorizou criar uma conta própria de testes no Broker e deixar um número de teste vinculado. Ainda não foi informado o domínio do Broker a administrar, o número e o contato destinatário. Não criar uma conta em uma origem presumida nem mover um número produtivo para preencher essa ausência.

## Preparação autorizada

1. Identificar a origem exata do Broker e conferir a imagem/revisão implantada. Se for necessário um Broker isolado novo, usar seu Compose oficial `infra/dokploy/compose.yaml`, projeto `jrc-broker-ura-hml`, volumes próprios, banco/Redis/armazenamento próprios e segredos novos. API, workers de mensagem/automação/IO/scheduler e sandbox devem usar a mesma revisão. Não apontar Evolution ou cofre para recursos produtivos como substitutos.
2. Criar organização/conta “JRC URA HML” pelos mecanismos oficiais de administração do Broker; registrar seu UUID e permissões sem exportar credenciais. Essa criação não comprova que o número está conectado.
3. Confirmar banco, Redis e storage exclusivos do serviço Conversas `jrcconversas-lab-app`. Seu Compose atual declara apenas init/Rails/Sidekiq e herda `.env`; portanto os recursos externos não podem ser inferidos pelo nome do serviço. O Compose de referência desta entrega provisiona recursos locais próprios.
4. Criar conta/caixa HML no Conversas, usando catálogo sintético autorizado. Caixa API: saudação e autoatribuição desativadas; remover associação AgentBot antiga por configuração legítima antes de ativar a autoridade nativa. Não criar AgentBot fictício.
5. Cadastrar credencial da integração pelo mecanismo criptografado existente, aprovar a origem, fazer registro/atestado e vincular a caixa pelo editor nativo. Conferir origem, organização, integração, conta, caixa, revisão e versão efetivas.
6. Criar o modelo OIA parcial, ajustar expediente/política de teste, selecionar os 13 destinos reais da HML e revisar os 26 caminhos. O texto anuncia pessoa e setor, mas a atribuição efetiva deve ser conferida por leitura canônica. Destino por ação: agente OU equipe.
7. Vincular somente o número de teste explicitamente identificado pelo usuário, com seu provider/instância reais. Quando houver QR/autenticação que exija participação do usuário, apresentar a etapa correspondente. Não desconectar nem migrar número existente sem identificar o recurso.
8. Com contato autorizado, executar T01–T20/OIA01–OIA13 e os 26 percursos no WhatsApp, incluindo POA 2/3, eventos repetidos, agente removido, concorrência humana, CSAT HTTPS e resposta registrada. Guardar recibos sanitizados com run ID, revisão, conta/caixa/conversa e resultado, distinguindo transporte sintético de provedor real.

## Publicação e reversão

Usar imagens novas por SHA e depois fixar por digest. Não sobrescrever tags anteriores. O workflow do Conversas é manual e exige três gates; o build final confere `.git_sha`, rótulo OCI, plataforma, Rails HTTP, PostgreSQL/Redis e Sidekiq. O smoke adicional executa um job Sidekiq nativo que comprova America/Sao_Paulo mantendo sistema/banco UTC.

Antes da mudança remota, registrar Compose, nomes de volumes, digest atual e configuração de domínio sem valores secretos. Migrations são para a HML identificada. A reversão usa a versão anterior da aplicação somente se compatível com o schema atual, pausando antes o binding/novas entradas e reconciliando efeitos incertos; não fazer downgrade destrutivo de banco, replay de UNKNOWN/FAILED nem restaurar backup produtivo. O bloqueio de legados deve ocorrer apenas no tráfego de HML.

## Bloqueios atuais

Origem do Broker; número e contato autorizados; confirmação do isolamento dos recursos remotos; exports/configurações completos de OIA, CRF e Íris. A ausência desses itens não impede gerar imagens e executar os testes independentes. Impede certificar entrega pelo WhatsApp e paridade integral de clientes.
