-- JRC Voice Quality Analytics - integracao JRC Conversas LAB3
-- Seguro para reexecutar. Nao apaga tabelas nem dados existentes.

alter table public.chamadas_pabx
  add column if not exists account_id bigint,
  add column if not exists user_id bigint,
  add column if not exists conversation_id bigint,
  add column if not exists inbox_id bigint,
  add column if not exists direction text,
  add column if not exists telefone_destino text,
  add column if not exists recording_url text;

alter table public.transcricoes_pabx
  add column if not exists account_id bigint;

alter table public.analises_qualidade_pabx
  add column if not exists account_id bigint;

update public.transcricoes_pabx t
set account_id = c.account_id
from public.chamadas_pabx c
where t.chamada_id = c.id
  and t.account_id is null
  and c.account_id is not null;

update public.analises_qualidade_pabx a
set account_id = c.account_id
from public.chamadas_pabx c
where a.chamada_id = c.id
  and a.account_id is null
  and c.account_id is not null;

create index if not exists idx_chamadas_pabx_account_id on public.chamadas_pabx(account_id);
create index if not exists idx_chamadas_pabx_account_call_id on public.chamadas_pabx(account_id, call_id);
create index if not exists idx_transcricoes_pabx_account_id on public.transcricoes_pabx(account_id);
create index if not exists idx_analises_qualidade_pabx_account_id on public.analises_qualidade_pabx(account_id);
create index if not exists idx_analises_qualidade_pabx_account_chamada on public.analises_qualidade_pabx(account_id, chamada_id);

create or replace view public.vw_qualidade_pabx_dashboard as
select
  aq.id                              as analise_id,
  c.id                               as chamada_id,
  c.account_id,
  c.user_id,
  c.conversation_id,
  c.inbox_id,
  c.call_id,
  c.arquivo_audio,
  c.telefone_origem,
  c.telefone_destino,
  c.ramal,
  c.agente,
  c.fila,
  c.direction,
  c.recording_url,
  c.duracao_segundos,
  c.data_chamada,
  c.status                           as status_chamada,
  t.texto_transcrito,
  t.modelo_transcricao,
  aq.resumo_conversa,
  aq.assuntos_abordados,
  aq.sentimento_cliente,
  aq.sentimento_atendente,
  aq.temperatura_conversa,
  aq.tom_cliente,
  aq.tom_atendente,
  aq.houve_agressividade_cliente,
  aq.houve_agressividade_atendente,
  aq.houve_empatia,
  aq.houve_cordialidade,
  aq.houve_interrupcao,
  aq.cliente_demonstrou_insatisfacao,
  aq.cliente_ameacou_cancelar,
  aq.cliente_mencionou_procon_anatel,
  aq.cliente_mencionou_processo,
  aq.problema_resolvido,
  aq.necessita_retorno,
  aq.risco_churn,
  aq.risco_reclamacao,
  aq.cordialidade,
  aq.empatia,
  aq.clareza_comunicacao,
  aq.dominio_assunto,
  aq.conducao_conversa,
  aq.resolucao_problema,
  aq.cumprimento_protocolo,
  aq.controle_emocional,
  aq.experiencia_cliente,
  aq.nota_final,
  aq.pontos_positivos,
  aq.pontos_negativos,
  aq.oportunidades_melhoria,
  aq.treinamento_recomendado,
  aq.classificacao_ligacao,
  aq.status_monitoria,
  aq.alerta_supervisao,
  aq.motivo_alerta,
  aq.confianca_transcricao,
  aq.observacao_transcricao,
  aq.payload_completo,
  aq.criado_em                       as analise_criada_em
from public.analises_qualidade_pabx aq
join public.chamadas_pabx c on aq.chamada_id = c.id
left join public.transcricoes_pabx t on t.chamada_id = c.id;

grant select on public.vw_qualidade_pabx_dashboard to service_role;
