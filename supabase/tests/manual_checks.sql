-- Verificações manuais das RPCs — rodar no SQL Editor do Supabase após o schema e o seed.
-- O bloco 1 roda inteiro (falha com ASSERT se algo divergir e imprime "OK" no fim).
-- Os blocos 2 e 3 devem ser executados um comando por vez (cada erro aborta a transação).

-- ---------------------------------------------------------------------------
-- 1. Pontuação, anti-fraude, idempotência e validações
-- ---------------------------------------------------------------------------
do $$
declare
  v_start   jsonb;
  v_session uuid;
  v_answers jsonb;
  v_result  jsonb;
begin
  -- start_quiz não pode expor resposta nem explicação.
  v_start := start_quiz('Teste Manual', 'Teste.Manual@Example.com ', 'intermediario', true);
  assert jsonb_array_length(v_start -> 'questions') = 5, 'deveria trazer 5 perguntas';
  assert not (v_start::text ~ '"(answer|explanation)"'), 'start_quiz vazou answer/explanation';
  v_session := (v_start ->> 'session_id')::uuid;

  -- Sessão iniciada há 2 min, todas as respostas corretas com tempos conhecidos:
  --   300 ms → 149 · 10000 ms → 125 · 20000 ms → 100 · 50 ms (→ 300) → 149 · 25000 ms (timeout) → 0
  update quiz_sessions set started_at = now() - interval '2 minutes' where id = v_session;

  select jsonb_agg(jsonb_build_object('question_id', q.id, 'answer', q.answer, 'time_ms', t.ms) order by s.ord)
    into v_answers
    from unnest((select question_ids from quiz_sessions where id = v_session)) with ordinality as s(id, ord)
    join questions q on q.id = s.id
    join (values (1, 300), (2, 10000), (3, 20000), (4, 50), (5, 25000)) as t(ord, ms) on t.ord = s.ord;

  v_result := submit_quiz(v_session, v_answers);
  assert (v_result ->> 'score')::int = 523,        format('score esperado 523, obtido %s', v_result ->> 'score');
  assert (v_result ->> 'correct_count')::int = 4,  format('acertos esperados 4, obtidos %s', v_result ->> 'correct_count');
  assert (v_result ->> 'total_time_ms')::int = 50600, format('tempo esperado 50600, obtido %s', v_result ->> 'total_time_ms');
  assert (v_result ->> 'ranked')::boolean,         'sessão deveria ser ranqueada';
  assert (v_result ->> 'rank') is not null,        'rank deveria vir preenchido';
  assert jsonb_array_length(v_result -> 'results') = 5, 'results deveria ter 5 itens';

  -- get_leaderboard: is_me marca o jogador da sessão (anexado mesmo fora do Top 1).
  assert (select count(*) from get_leaderboard('intermediario', 1, v_session)
           where is_me and position = (v_result ->> 'rank')::bigint) = 1, 'is_me deveria marcar a linha do jogador';
  assert not exists (select 1 from get_leaderboard('intermediario') where is_me), 'sem sessão, nenhuma linha deveria ter is_me';

  -- Idempotência: reenviar devolve o mesmo resultado.
  assert submit_quiz(v_session, v_answers) = v_result, 'reenvio deveria devolver o mesmo resultado';

  -- Anti-fraude: tempos declarados (50 s) maiores que o tempo real decorrido (~0 s).
  v_start := start_quiz('Teste Manual', 'teste.manual@example.com', 'intermediario', true);
  v_session := (v_start ->> 'session_id')::uuid;
  select jsonb_agg(jsonb_build_object('question_id', id, 'answer', true, 'time_ms', 10000))
    into v_answers
    from unnest((select question_ids from quiz_sessions where id = v_session)) as id;
  v_result := submit_quiz(v_session, v_answers);
  assert not (v_result ->> 'ranked')::boolean, 'sessão rápida demais deveria ter ranked = false';

  -- Anti-fraude: envio mais de 5 min após o início.
  v_start := start_quiz('Teste Manual', 'teste.manual@example.com', 'intermediario', true);
  v_session := (v_start ->> 'session_id')::uuid;
  update quiz_sessions set started_at = now() - interval '6 minutes' where id = v_session;
  select jsonb_agg(jsonb_build_object('question_id', id, 'answer', null, 'time_ms', 20000))
    into v_answers
    from unnest((select question_ids from quiz_sessions where id = v_session)) as id;
  v_result := submit_quiz(v_session, v_answers);
  assert not (v_result ->> 'ranked')::boolean, 'envio tardio deveria ter ranked = false';
  assert (v_result ->> 'score')::int = 0, 'timeouts deveriam valer 0';

  -- Validações de entrada.
  begin
    perform start_quiz('Teste Manual', 'teste.manual@example.com', 'iniciante', false);
    raise exception 'esperava CONSENT_REQUIRED';
  exception when others then assert sqlerrm = 'CONSENT_REQUIRED', sqlerrm;
  end;
  begin
    perform start_quiz(' A ', 'teste.manual@example.com', 'iniciante', true);
    raise exception 'esperava INVALID_NAME';
  exception when others then assert sqlerrm = 'INVALID_NAME', sqlerrm;
  end;
  begin
    perform start_quiz('Fulano Merda', 'teste.manual@example.com', 'iniciante', true);
    raise exception 'esperava BLOCKED_NAME';
  exception when others then assert sqlerrm = 'BLOCKED_NAME', sqlerrm;
  end;
  begin
    perform start_quiz('Teste Manual', 'sem-arroba', 'iniciante', true);
    raise exception 'esperava INVALID_EMAIL';
  exception when others then assert sqlerrm = 'INVALID_EMAIL', sqlerrm;
  end;
  begin
    perform submit_quiz(gen_random_uuid(), '[]'::jsonb);
    raise exception 'esperava SESSION_NOT_FOUND';
  exception when others then assert sqlerrm = 'SESSION_NOT_FOUND', sqlerrm;
  end;
  begin
    v_start := start_quiz('Teste Manual', 'teste.manual@example.com', 'avancado', true);
    perform submit_quiz((v_start ->> 'session_id')::uuid, '[{"question_id": 1, "answer": true, "time_ms": 1000}]'::jsonb);
    raise exception 'esperava INVALID_ANSWERS';
  exception when others then assert sqlerrm = 'INVALID_ANSWERS', sqlerrm;
  end;

  -- Nome: tabs/quebras de linha nas pontas são aparadas.
  perform start_quiz(E'\tTeste   Manual\n', 'teste.manual@example.com', 'iniciante', true);
  assert (select name from players where email = 'teste.manual@example.com') = 'Teste Manual', 'nome deveria ser aparado';

  -- Palavras bloqueadas com metacaracteres de regex são comparadas literalmente.
  insert into blocked_words (word) values ('c++'), ('a.b') on conflict do nothing;
  perform start_quiz('Teste axb', 'teste.manual@example.com', 'iniciante', true);  -- não pode dar erro de regex nem bloquear
  begin
    perform start_quiz('Teste a.b', 'teste.manual@example.com', 'iniciante', true);
    raise exception 'esperava BLOCKED_NAME';
  exception when others then assert sqlerrm = 'BLOCKED_NAME', sqlerrm;
  end;
  delete from blocked_words where word in ('c++', 'a.b');

  -- Limpeza dos dados de teste (cascade em sessões e respostas).
  delete from players where email = 'teste.manual@example.com';

  raise notice 'OK — todas as verificações passaram';
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Ranking público (deve trazer no máximo 10 linhas, sem e-mail nem player_id)
-- ---------------------------------------------------------------------------
select * from get_leaderboard('iniciante');

-- ---------------------------------------------------------------------------
-- 3. Acesso como anon — execute cada transação separadamente.
--    Esperado: erro "permission denied" nas tabelas, na view e na função interna;
--    sucesso apenas em get_leaderboard.
-- ---------------------------------------------------------------------------
begin; set local role anon; select * from players;                      rollback;
begin; set local role anon; select * from questions;                    rollback;
begin; set local role anon; select * from question_stats;               rollback;
begin; set local role anon; select * from _level_ranking('iniciante');  rollback;
begin; set local role anon; select * from get_leaderboard('iniciante'); rollback;
