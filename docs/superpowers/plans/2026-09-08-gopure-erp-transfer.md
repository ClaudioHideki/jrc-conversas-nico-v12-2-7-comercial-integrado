# GoPure: ERP nas conversas e transferência

Autorização: usuário solicitou implementar e empacotar, usando os códigos de operadora 3 e solicitante 4912. O cliente consultado pelo CNPJ retorna códigos próprios (152/536); não sobrescrever essa identidade sem confirmação.

## Desenho

Rails mantém autorização, configurações por conta e vínculo por contato em tabelas próprias. Um serviço Node dedicado executa somente rotas ERP fixas, sanitiza respostas e mantém tokens fora do runtime elizaOS. O runtime recebe uma nova fonte `erp`, com referência ao vínculo e versão para revogação. Modo fixture é explícito e usa dados sintéticos; modo real exige confirmação cadastral e permite inicialmente leitura. Abertura externa depende de classificação válida, simulação e revisão, permanecendo desativada enquanto esses critérios não forem satisfeitos.

## Execução

- [x] Serviço ERP: autenticação interna, allowlist de conta, resolução CNPJ, leitura de chamados, respostas minimizadas, fixtures e testes Node sem Docker.
- [x] Rails: configuração administrativa, vínculo por contato, contexto ERP e revogação de resultados; interface junto ao painel NICO.
- [x] Contrato dos sete especialistas: fonte ERP, limitações corretas, simulações com dados sintéticos e provedor real quando acessível.
- [ ] Testes de regressão e instruções de homologação no destino. Registrar separadamente testes executados e pendentes.
- [ ] Pacote atualizado com fonte, scripts de compilação/restauração, configuração segura e relatório. Não incluir tokens em ZIP aberto. Não afirmar compilação Docker concluída nesta máquina.

## Aceite

Tenant sem habilitação não consulta ERP; contato sem vínculo não recebe contexto; códigos e tokens não atravessam tenants; falha ERP não produz dados inventados; evidência revogada deixa de ser acessível; nenhuma simulação envia mensagem pública nem cria registro externo. Compilação e testes Rails no destino precisam passar antes de uso operacional.

