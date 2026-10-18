-- Quiz Claude Code — schema, RLS, RPCs e view de análise.
-- Executar uma vez no SQL Editor do Supabase (ou via Supabase CLI), antes do seed.sql.
--
-- Modelo de segurança: todas as tabelas têm RLS ativo e NENHUMA policy; o front
-- acessa o banco apenas pelas RPCs start_quiz, submit_quiz e get_leaderboard
-- (security definer). Erros de negócio são levantados como `raise exception '<CODIGO>'`
-- e traduzidos para PT-BR em js/api.js.

-- ---------------------------------------------------------------------------
-- Tipos e tabelas
-- ---------------------------------------------------------------------------

create type quiz_level as enum ('iniciante', 'intermediario', 'avancado');

create table questions (
  id           bigint generated always as identity primary key,
  level        quiz_level not null,
  statement    text not null,
  answer       boolean not null,
  explanation  text not null,
  doc_url      text,
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);

create table players (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (char_length(name) between 2 and 40),
  email        text not null unique,          -- sempre lowercase
  consent_at   timestamptz not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table quiz_sessions (
  id             uuid primary key default gen_random_uuid(),
  player_id      uuid not null references players(id) on delete cascade,
  level          quiz_level not null,
  question_ids   bigint[] not null,
  started_at     timestamptz not null default now(),
  finished_at    timestamptz,
  score          int,
  correct_count  int,
  total_time_ms  int,
  ranked         boolean not null default true
);

create table session_answers (
  session_id   uuid not null references quiz_sessions(id) on delete cascade,
  question_id  bigint not null references questions(id),
  answer       boolean,          -- null = tempo esgotado
  is_correct   boolean not null,
  time_ms      int not null,
  points       int not null,
  primary key (session_id, question_id)
);

-- Palavras bloqueadas em nomes do ranking (gerenciar pelo Studio; sempre minúsculas).
create table blocked_words (
  word  text primary key check (word = lower(word) and char_length(word) > 0)
);

create index on questions (level) where active;
-- Serve o distinct on (player_id) de _level_ranking: melhor sessão de cada jogador sem ordenar o nível inteiro.
create index on quiz_sessions (level, player_id, score desc, total_time_ms asc, finished_at asc) where finished_at is not null and ranked;
create index on quiz_sessions (player_id, started_at);

-- ---------------------------------------------------------------------------
-- RLS: ativo em todas as tabelas, sem policies. Além disso, revoga os
-- privilégios padrão que o Supabase concede ao anon/authenticated no schema public.
-- ---------------------------------------------------------------------------

alter table questions       enable row level security;
alter table players         enable row level security;
alter table quiz_sessions   enable row level security;
alter table session_answers enable row level security;
alter table blocked_words   enable row level security;

revoke all on table questions, players, quiz_sessions, session_answers, blocked_words
  from anon, authenticated;

-- ---------------------------------------------------------------------------
-- _level_ranking: melhor sessão ranqueada e finalizada de cada jogador no nível,
-- com posição. Fonte única da ordenação do ranking (usada por get_leaderboard e
-- submit_quiz). Interna: sem grant ao anon; roda com os privilégios de quem chama
-- (as RPCs security definer).
-- ---------------------------------------------------------------------------

create or replace function _level_ranking(p_level quiz_level)
returns table (
  player_id      uuid,
  "position"     bigint,
  name           text,
  score          int,
  correct_count  int,
  total_time_ms  int,
  finished_at    timestamptz
)
language sql
stable
set search_path = public
as $$
  with best as (
    select distinct on (s.player_id)
           s.player_id, s.score, s.correct_count, s.total_time_ms, s.finished_at
      from quiz_sessions s
     where s.level = p_level
       and s.finished_at is not null
       and s.ranked
     order by s.player_id, s.score desc, s.total_time_ms asc, s.finished_at asc
  )
  select b.player_id,
         row_number() over (order by b.score desc, b.total_time_ms asc, b.finished_at asc),
         p.name, b.score, b.correct_count, b.total_time_ms, b.finished_at
    from best b
    join players p on p.id = b.player_id
   order by 2;
$$;

-- ---------------------------------------------------------------------------
-- start_quiz: valida o jogador, aplica rate limit, cria a sessão e devolve
-- 5 perguntas SEM resposta e SEM explicação.
-- ---------------------------------------------------------------------------

create or replace function start_quiz(p_name text, p_email text, p_level quiz_level, p_consent boolean)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  -- Colapsa antes de aparar: btrim() só remove espaços, não tabs/quebras de linha.
  v_name       text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  v_email      text := lower(btrim(coalesce(p_email, '')));
  v_player_id  uuid;
  v_session_id uuid;
  v_ids        bigint[];
  v_questions  jsonb;
begin
  if p_consent is not true then
    raise exception 'CONSENT_REQUIRED';
  end if;

  if char_length(v_name) not between 2 and 40 then
    raise exception 'INVALID_NAME';
  end if;

  -- A palavra é escapada (todo caractere não alfanumérico vira literal) antes de virar regex.
  if exists (select 1 from blocked_words w
              where v_name ~* ('\m' || regexp_replace(w.word, '(\W)', '\\\1', 'g') || '\M')) then
    raise exception 'BLOCKED_NAME';
  end if;

  if char_length(v_email) > 254 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'INVALID_EMAIL';
  end if;

  -- O upsert trava a linha do jogador até o fim da transação: chamadas simultâneas
  -- do mesmo e-mail esperam aqui e só depois contam as sessões (já commitadas).
  -- Se o rate limit estourar, o raise desfaz o upsert.
  insert into players (name, email, consent_at)
  values (v_name, v_email, now())
  on conflict (email) do update
    set name = excluded.name,
        consent_at = excluded.consent_at,
        updated_at = now()
  returning id into v_player_id;

  -- Rate limit: 30 sessões por e-mail por hora.
  if (select count(*) from quiz_sessions
       where player_id = v_player_id
         and started_at > now() - interval '1 hour') >= 30 then
    raise exception 'RATE_LIMIT';
  end if;

  select array_agg(q.id order by q.r)
    into v_ids
    from (select id, random() as r
            from questions
           where level = p_level and active
           order by r
           limit 5) q;

  if coalesce(array_length(v_ids, 1), 0) < 5 then
    raise exception 'NOT_ENOUGH_QUESTIONS';
  end if;

  insert into quiz_sessions (player_id, level, question_ids)
  values (v_player_id, p_level, v_ids)
  returning id into v_session_id;

  select jsonb_agg(jsonb_build_object('id', q.id, 'statement', q.statement) order by t.ord)
    into v_questions
    from unnest(v_ids) with ordinality as t(id, ord)
    join questions q on q.id = t.id;

  return jsonb_build_object('session_id', v_session_id, 'questions', v_questions);
end;
$$;

-- ---------------------------------------------------------------------------
-- submit_quiz: valida, pontua (PRD §6.4), grava e devolve o resultado completo.
-- Idempotente: se a sessão já foi finalizada, devolve o resultado gravado.
-- ---------------------------------------------------------------------------

create or replace function submit_quiz(p_session_id uuid, p_answers jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_session    quiz_sessions%rowtype;
  v_sum_ms     int;
  v_elapsed_ms numeric;
  v_rank       bigint;
  v_best       int;
  v_results    jsonb;
begin
  select * into v_session from quiz_sessions where id = p_session_id for update;
  if not found then
    raise exception 'SESSION_NOT_FOUND';
  end if;

  if v_session.finished_at is null then
    -- Formato: array de 5 objetos { question_id: number, answer: boolean|null, time_ms: number }.
    if p_answers is null
       or jsonb_typeof(p_answers) <> 'array'
       or jsonb_array_length(p_answers) <> 5
       or exists (
            select 1
              from jsonb_array_elements(p_answers) e
             where jsonb_typeof(e) <> 'object'
                or jsonb_typeof(e -> 'question_id') is distinct from 'number'
                or coalesce(jsonb_typeof(e -> 'answer'), 'null') not in ('boolean', 'null')
                or jsonb_typeof(e -> 'time_ms') is distinct from 'number')
    then
      raise exception 'INVALID_ANSWERS';
    end if;

    -- Mesmas 5 perguntas da sessão, sem repetição.
    if (select count(distinct (e ->> 'question_id')::numeric)
          from jsonb_array_elements(p_answers) e) <> 5
       or exists (
            select 1
              from jsonb_array_elements(p_answers) e
             where not ((e ->> 'question_id')::numeric = any (v_session.question_ids::numeric[])))
    then
      raise exception 'INVALID_ANSWERS';
    end if;

    -- Normalização: time_ms < 300 → 300; > 20500 → tempo esgotado. Tempo gravado limitado a 20000.
    with raw as (
      select (e ->> 'question_id')::bigint as question_id,
             (e ->> 'time_ms')::numeric    as raw_ms,
             case when jsonb_typeof(e -> 'answer') = 'boolean'
                  then (e ->> 'answer')::boolean end as raw_answer
        from jsonb_array_elements(p_answers) e
    ), norm as (
      select question_id,
             case when raw_ms > 20500 then null else raw_answer end as answer,
             least(greatest(round(least(raw_ms, 20500)), 300), 20000)::int as time_ms
        from raw
    )
    insert into session_answers (session_id, question_id, answer, is_correct, time_ms, points)
    select p_session_id,
           n.question_id,
           n.answer,
           coalesce(n.answer = q.answer, false),
           n.time_ms,
           case when n.answer = q.answer
                then 100 + (50 * (20000 - n.time_ms)) / 20000   -- divisão inteira = floor (valores ≥ 0)
                else 0 end
      from norm n
      join questions q on q.id = n.question_id;

    select sum(time_ms) into v_sum_ms from session_answers where session_id = p_session_id;
    v_elapsed_ms := extract(epoch from (now() - v_session.started_at)) * 1000;

    update quiz_sessions s
       set finished_at   = now(),
           score         = a.score,
           correct_count = a.correct_count,
           total_time_ms = v_sum_ms,
           -- Anti-fraude: tempo real no servidor menor que o declarado (−2 s de tolerância)
           -- ou envio mais de 5 min após o início → sessão salva, mas fora do ranking.
           ranked        = v_elapsed_ms >= v_sum_ms - 2000 and v_elapsed_ms <= 300000
      from (select sum(points)::int as score,
                   (count(*) filter (where is_correct))::int as correct_count
              from session_answers
             where session_id = p_session_id) a
     where s.id = p_session_id
    returning s.* into v_session;
  end if;

  select r.position, r.score
    into v_rank, v_best
    from _level_ranking(v_session.level) r
   where r.player_id = v_session.player_id;

  select jsonb_agg(jsonb_build_object(
           'question_id',    q.id,
           'statement',      q.statement,
           'answer',         sa.answer,
           'correct_answer', q.answer,
           'is_correct',     sa.is_correct,
           'points',         sa.points,
           'explanation',    q.explanation,
           'doc_url',        q.doc_url
         ) order by t.ord)
    into v_results
    from unnest(v_session.question_ids) with ordinality as t(id, ord)
    join session_answers sa on sa.session_id = v_session.id and sa.question_id = t.id
    join questions q on q.id = t.id;

  return jsonb_build_object(
    'score',         v_session.score,
    'correct_count', v_session.correct_count,
    'total_time_ms', v_session.total_time_ms,
    'ranked',        v_session.ranked,
    'rank',          v_rank,
    'best_score',    v_best,
    'results',       v_results
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- get_leaderboard: Top N do nível (padrão 10, máx. 50). Nunca retorna e-mail nem player_id.
-- p_session_id (opcional): sessão mais recente do jogador no navegador. A linha
-- desse jogador vem com is_me = true e, se estiver fora do Top N, é anexada ao fim.
-- ---------------------------------------------------------------------------

create or replace function get_leaderboard(p_level quiz_level, p_limit int default 10, p_session_id uuid default null)
returns table (
  "position"     bigint,
  name           text,
  score          int,
  correct_count  int,
  total_time_ms  int,
  finished_at    timestamptz,
  is_me          boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select s.player_id from quiz_sessions s where s.id = p_session_id
  )
  select r.position, r.name, r.score, r.correct_count, r.total_time_ms, r.finished_at,
         coalesce(r.player_id = (select player_id from me), false)
    from _level_ranking(p_level) r
   where r.position <= least(greatest(coalesce(p_limit, 10), 1), 50)
      or r.player_id = (select player_id from me)
   order by r.position;
$$;

-- ---------------------------------------------------------------------------
-- Privilégios das funções: o Supabase concede EXECUTE por padrão; revogamos tudo
-- e liberamos apenas as 3 RPCs públicas.
-- ---------------------------------------------------------------------------

revoke all on function _level_ranking(quiz_level)                   from public, anon, authenticated;
revoke all on function start_quiz(text, text, quiz_level, boolean)  from public, anon, authenticated;
revoke all on function submit_quiz(uuid, jsonb)                     from public, anon, authenticated;
revoke all on function get_leaderboard(quiz_level, int, uuid)       from public, anon, authenticated;

grant execute on function start_quiz(text, text, quiz_level, boolean) to anon, authenticated;
grant execute on function submit_quiz(uuid, jsonb)                    to anon, authenticated;
grant execute on function get_leaderboard(quiz_level, int, uuid)      to anon, authenticated;

-- ---------------------------------------------------------------------------
-- question_stats: análise por pergunta, somente para o Studio.
-- security_invoker para respeitar o RLS; sem grant ao anon/authenticated.
-- ---------------------------------------------------------------------------

create view question_stats with (security_invoker = true) as
select q.id,
       q.level,
       q.statement,
       q.active,
       count(sa.session_id) as total_answers,
       round(100.0 * count(sa.session_id) filter (where sa.is_correct)
             / nullif(count(sa.session_id), 0), 1) as pct_correct,
       round(100.0 * count(sa.session_id) filter (where sa.answer is null)
             / nullif(count(sa.session_id), 0), 1) as pct_timeout,
       round(avg(sa.time_ms)) as avg_time_ms
  from questions q
  left join session_answers sa on sa.question_id = q.id
 group by q.id;

revoke all on question_stats from anon, authenticated;
