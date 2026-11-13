<!-- jrc-operational-init:v1 -->
# Visão do sistema — JRC Conversas NICO — frente legada de URA

## Propósito e fronteira

Repositório específico da frente NICO/URA legada; não substituir o núcleo LAB2 nem presumir implantação.

**Stack:** Ruby/Rails, Vue, PostgreSQL, Redis e integrações NICO/URA.

**Natureza:** Brownfield. **Tipo de raiz:** application.

## Fluxo lógico

Canal → inbox/contexto → Flow/URA → destino configurado → atendimento humano; pausa e atribuição seguem política da empresa.

Esta é uma visão de responsabilidades baseada em fontes locais, não um levantamento dos hosts efetivos. Versão em execução, topologia física, portas produtivas e imagem implantada não foram verificadas neste bootstrap.

## Controle de versões

- Data da leitura: 2026-11-13.
- Branch local: `codex/ura-nativa-hml-20261104`.
- HEAD de origem antes da documentação: `f6a83b3ebc68a4f74ebbff11d9046037db2a267b`.
- Origem Git: `https://github.com/ClaudioHideki/jrc-conversas-nico-v12-2-7-comercial-integrado.git`.
- [Contexto e versões declaradas](repository-context-init-v1.json).

Esse HEAD é a base documental observada e não será atualizado para fingir versão produtiva. A revisão documental, o software, o commit, a imagem publicada e a imagem em execução são informações distintas.

## Fontes atuais

- [AGENTS.md](<../../AGENTS.md>)
- [README.md](<../../README.md>)
- [package.json](<../../package.json>)
- [Gemfile](<../../Gemfile>)
- [db/schema.rb](<../../db/schema.rb>)

## Pendências conhecidas

- Identificar quais incrementos já foram incorporados no LAB2 antes de promover trabalho.
- Preservar diferenças de contrato e permissões da frente legada.

O padrão de arquitetura JRC completo usa prancha integrada, fluxos, runtimes e quadro de versões com fontes; a referência visual aprovada é a arquitetura R03/R04 de 13/11/2026. Este índice não substitui aquelas pranchas nem os planos existentes.
