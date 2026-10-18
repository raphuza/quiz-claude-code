# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

MVP implemented from `prd.md` (PT-BR), the approved PRD for a True/False quiz about Claude Code. Consult it for the functional requirements (RF01–RF10), acceptance criteria (§7) and the 45-question seed (Appendix A). All user-facing text is **PT-BR**.

## Stack and commands

- Plain HTML/CSS/JS ES modules (`type="module"`) — **no framework, no bundler, no build step, no npm dependencies**.
- Supabase (Postgres + RPC) as backend; `supabase-js` v2 loaded from CDN: `import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm'`.
- Run locally with any static server (ES modules don't work over `file://`): `npx serve .`
- Database: run `supabase/migrations/001_schema.sql` then `supabase/seed.sql` in the Supabase SQL Editor (or Supabase CLI). There is no automated test suite; `supabase/tests/manual_checks.sql` is the RPC check script (block 1 asserts scoring/anti-fraud/idempotency/validation and must print `OK`; block 3 checks that `anon` is denied on tables, view and `_level_ranking`). Keep it in sync when changing RPC behavior.
- Config: `js/config.js` (versioned on purpose — anon key is public, no build step) holds `SUPABASE_URL`/`SUPABASE_ANON_KEY`; `api.js` shows a "not configured" error while it still has the placeholders.
- Deploy: static site on Vercel from repo root, no build command. `vercel.json` holds the security headers (CSP: `script-src` jsdelivr, `style-src` Google Fonts, `font-src` gstatic, `connect-src` `*.supabase.co`). `.vercelignore` excludes `prd.md` and `supabase/` because they contain the answers — keep any new file with answers out of the deploy.

## Layout (PRD §6.2)

- `index.html` — single page containing all screens as sections.
- `js/main.js` — bootstrap + state machine: `HOME → PLAYER_FORM → LEVEL_SELECT → LOADING → QUESTION ×5 → SUBMITTING → RESULT → (REVIEW | LEADERBOARD)`; `HOME → LEADERBOARD`; any network failure → `ERROR` with "Tentar novamente".
- `js/api.js` (Supabase client + RPC calls), `js/quiz.js` (round flow), `js/timer.js` (20s timer via `requestAnimationFrame`/`performance.now()`), `js/ui.js` (rendering), `js/storage.js` (`localStorage` wrapped in try/catch: player name/email, theme).
- `css/styles.css` — color tokens on `:root`, redefined in `@media (prefers-color-scheme: dark)` and `[data-theme="dark"|"light"]`. Palette: terracotta `#D97757`, cream `#F5F0E8`, graphite `#1F1E1D`.

## Architecture rules that span files

**Security model — the client is untrusted:**
- All tables (`questions`, `players`, `quiz_sessions`, `session_answers`) have RLS enabled with **no policies** for `anon`/`authenticated`. The front end never uses `supabase.from(...)`; it only calls three RPCs: `start_quiz`, `submit_quiz`, `get_leaderboard`.
- RPCs are `security definer`, `set search_path = public`, `grant execute ... to anon`. The `question_stats` view is Studio-only (no grant to anon).
- `start_quiz` returns questions **without** `answer`/`explanation`; these appear only in the `submit_quiz` response. Never leak them earlier.
- Score is computed **only on the server**; the client never computes or displays a provisional score.
- No RPC ever returns `email` or `player_id`.
- Render dynamic data with `textContent` only — never `innerHTML` with data.

**RPC contracts (`js/api.js` and the SQL must agree — PRD §6.6 has the exact JSON shapes):**
- Level enum `quiz_level` values are unaccented: `'iniciante' | 'intermediario' | 'avancado'` (UI labels carry the accents).
- `start_quiz(p_name, p_email, p_level, p_consent)` → `{ session_id, questions: [{ id, statement }] }`.
- `submit_quiz(p_session_id, p_answers jsonb)` with `p_answers = [{ question_id, answer: true|false|null, time_ms }]` ×5 → `{ score, correct_count, total_time_ms, ranked, rank, best_score, results: [...] }`; the RESULT and REVIEW screens render only from this response.
- `get_leaderboard(p_level, p_limit default 10, p_session_id default null)` → `[{ position, name, score, correct_count, total_time_ms, finished_at, is_me }]`: Top N plus, when `p_session_id` is given, that session's player row (`is_me = true`), appended even if outside the Top N. `api.getLeaderboard` splits it into `{ rows, me }`.
- Manual RLS check (acceptance §7): with the anon key, `supabase.from('players').select()` must return empty/error.
- Business errors are `raise exception '<CODE>'` (`CONSENT_REQUIRED`, `INVALID_NAME`, `BLOCKED_NAME`, `INVALID_EMAIL`, `RATE_LIMIT`, `NOT_ENOUGH_QUESTIONS`, `SESSION_NOT_FOUND`, `INVALID_ANSWERS`); `api.js` maps the code (`error.message`) to PT-BR text and `main.js` routes form-field codes back to `PLAYER_FORM`. A new code needs entries in both.
- Ranking order lives only in the internal `_level_ranking(level)` function (no grant to anon), used by both `get_leaderboard` and `submit_quiz` (`rank`/`best_score`). Supabase grants EXECUTE/table privileges to anon by default, so every new function/table/view needs explicit `revoke` (and views `security_invoker = true`).
- `submit_quiz` is idempotent: an already-finished session returns its stored result (lets "Tentar novamente" resubmit safely).
- The player's leaderboard highlight comes from the server's `is_me` flag: `main.js` keeps the last `session_id` in memory (`state.sessionId`, cleared on "Não sou eu" or an e-mail change) and passes it to `get_leaderboard`; identity is never exposed.

**Scoring and anti-fraud (in `submit_quiz`, PRD §6.4):**
- Correct = 100 + `floor(50 * (20000 - time_ms) / 20000)` (time clamped to [0, 20000]); wrong/timeout (`answer = null`) = 0; max 750.
- `time_ms` < 300 → 300; > 20500 → treat as timeout.
- Session must exist, be unfinished, and match the same 5 `question_ids`.
- Mark `ranked = false` (but still save) if server elapsed time < sum(`time_ms`) − 2s, or submitted > 5 min after `started_at`.
- `start_quiz` rate limit: 30 sessions per email per hour; also validates consent = true, email regex, name 2–40 chars after trim, blocked-word list; upserts player by lowercased email (updates name).

**Leaderboard:** best ranked, finished session per player per level; order `score desc, total_time_ms asc, finished_at asc`; Top 10.

**Quiz UX constraints:** after answering, show neutral "Resposta registrada" for ~400 ms (never reveal correctness until review); keyboard shortcuts `V`/`←` = Verdadeiro, `F`/`→` = Falso; prevent double answers; `aria-live="polite"` timer announcements only at 10s and 5s; respect `prefers-reduced-motion`; mobile-first down to 320 px.

## Content

Questions live only in the database (managed via SQL/Supabase Studio; disable with `active = false`). In `seed.sql`, expand the Appendix A "Link" column to full URLs: `https://code.claude.com/docs/en/<slug>`.
