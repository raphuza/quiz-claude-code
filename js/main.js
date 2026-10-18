// Bootstrap e máquina de estados do front:
// HOME → PLAYER_FORM → LEVEL_SELECT → LOADING → QUESTION ×5 → SUBMITTING → RESULT → (REVIEW | LEADERBOARD)
// HOME → LEADERBOARD; qualquer falha de rede → ERROR (com "Tentar novamente").

import * as api from './api.js';
import * as storage from './storage.js';
import * as ui from './ui.js';
import { LEVELS } from './ui.js';
import { createRound } from './quiz.js';

// Estados que reaproveitam a seção de outro.
const SCREEN_OF = { SUBMITTING: 'LOADING' };

// Erros de validação do start_quiz voltam para o formulário, no campo certo.
const FORM_ERROR_FIELD = {
  INVALID_NAME: 'name',
  BLOCKED_NAME: 'name',
  INVALID_EMAIL: 'email',
  CONSENT_REQUIRED: 'consent',
};

// Erros em que reenviar não adianta: a saída é uma nova rodada.
const RESTART_ROUND_ERRORS = new Set(['SESSION_NOT_FOUND', 'INVALID_ANSWERS']);

// Erros do start_quiz em que repetir o mesmo nível não adianta: volta à escolha de nível.
const PICK_LEVEL_ERRORS = new Set(['NOT_ENOUGH_QUESTIONS', 'RATE_LIMIT']);

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const LEVEL_KEYS = Object.keys(LEVELS);

const state = {
  current: null,
  player: null,            // { name, email } — validado nesta visita
  sessionId: null,         // última sessão do jogador (identifica a linha dele no ranking)
  level: null,             // nível da rodada atual/última
  round: null,
  result: null,            // última resposta de submit_quiz
  leaderboardLevel: LEVEL_KEYS[0],
  leaderboardReturn: 'HOME',
  retry: null,             // ação repetida pelo botão "Tentar novamente"
};

function go(next, options) {
  state.current = next;
  ui.showScreen(SCREEN_OF[next] ?? next, options);
}

function handleError(err, retry) {
  const code = err instanceof api.ApiError ? err.code : 'UNKNOWN';
  const message = err instanceof api.ApiError ? err.message : 'Ocorreu um erro inesperado. Tente novamente.';
  if (!(err instanceof api.ApiError)) console.error(err);

  if (FORM_ERROR_FIELD[code]) {
    openPlayerForm();
    state.player = null; // recusado pelo servidor: só volta a valer após novo envio do formulário
    ui.showFormErrors({ [FORM_ERROR_FIELD[code]]: message });
    return;
  }
  state.retry = retry;
  ui.renderError(message);
  go('ERROR');
}

// ---------- Jogador e nível ----------

function openPlayerForm() {
  ui.fillPlayerForm(state.player ?? storage.getPlayer());
  go('PLAYER_FORM');
}

function validatePlayer({ name, email, consent }) {
  const errors = {};
  const nameLength = [...name].length;
  if (nameLength < 2 || nameLength > 40) errors.name = 'Informe um nome entre 2 e 40 caracteres.';
  if (email.length > 254 || !EMAIL_RE.test(email)) errors.email = 'Informe um e-mail válido.';
  if (!consent) errors.consent = 'Marque o consentimento para continuar.';
  return errors;
}

function submitPlayerForm(event) {
  event.preventDefault();
  const raw = ui.readPlayerForm();
  const player = {
    name: raw.name.trim().replace(/\s+/g, ' '),
    email: raw.email.trim().toLowerCase(),
  };
  const errors = validatePlayer({ ...player, consent: raw.consent });
  ui.showFormErrors(errors);
  if (Object.keys(errors).length) return;

  if (player.email !== state.player?.email) state.sessionId = null;
  state.player = player; // salvo no localStorage só depois que o start_quiz aceitar
  openLevelSelect();
}

function openLevelSelect() {
  ui.renderLevelSelect(state.player.name);
  go('LEVEL_SELECT');
}

function notMe() {
  storage.clearPlayer();
  state.player = null;
  state.sessionId = null;
  ui.fillPlayerForm(null);
  ui.focusPlayerName();
}

// ---------- Rodada ----------

async function startRound(level) {
  if (!state.player) {
    openPlayerForm();
    return;
  }
  state.level = level;
  ui.setLoading('Sorteando perguntas…');
  go('LOADING');
  try {
    const data = await api.startQuiz({ ...state.player, level });
    storage.savePlayer(state.player);
    state.sessionId = data.session_id;
    state.round = createRound({
      sessionId: data.session_id,
      questions: data.questions,
      levelLabel: LEVELS[level].label,
      onComplete: submitRound,
    });
    go('QUESTION', { focus: false });
    state.round.start();
  } catch (err) {
    const pickLevel = err instanceof api.ApiError && PICK_LEVEL_ERRORS.has(err.code);
    handleError(err, pickLevel ? openLevelSelect : () => startRound(level));
  }
}

async function submitRound(payload) {
  state.round = null;
  ui.setLoading('Calculando sua pontuação…');
  go('SUBMITTING');
  try {
    const result = await api.submitQuiz(payload.sessionId, payload.answers);
    state.result = result;
    ui.renderResult(result, LEVELS[state.level].label);
    go('RESULT');
  } catch (err) {
    const restart = err instanceof api.ApiError && RESTART_ROUND_ERRORS.has(err.code);
    handleError(err, restart ? () => startRound(state.level) : () => submitRound(payload));
  }
}

// ---------- Ranking ----------

let leaderboardRequest = 0;

function openLeaderboard() {
  state.leaderboardReturn = state.current === 'RESULT' || state.current === 'REVIEW' ? state.current : 'HOME';
  go('LEADERBOARD');
  loadLeaderboard(state.level ?? state.leaderboardLevel);
}

async function loadLeaderboard(level) {
  state.leaderboardLevel = level;
  ui.selectLeaderboardTab(level);
  ui.setLeaderboardStatus('Carregando ranking…');
  const request = ++leaderboardRequest;
  // Resposta obsoleta: outra aba foi escolhida ou o jogador já saiu do ranking.
  const stale = () => request !== leaderboardRequest || state.current !== 'LEADERBOARD';
  try {
    const { rows, me } = await api.getLeaderboard(level, state.sessionId);
    if (stale()) return;
    ui.renderLeaderboard(rows, me, LEVELS[level].label);
  } catch (err) {
    if (stale()) return;
    handleError(err, () => {
      go('LEADERBOARD');
      loadLeaderboard(level);
    });
  }
}

function onTabKeydown(event) {
  const last = LEVEL_KEYS.length - 1;
  const current = LEVEL_KEYS.indexOf(state.leaderboardLevel);
  const target = {
    ArrowLeft: current === 0 ? last : current - 1,
    ArrowRight: current === last ? 0 : current + 1,
    Home: 0,
    End: last,
  }[event.key];
  if (target === undefined) return;
  event.preventDefault();
  const level = LEVEL_KEYS[target];
  document.getElementById(`tab-${level}`).focus();
  loadLeaderboard(level);
}

// ---------- Tema ----------

const darkQuery = window.matchMedia('(prefers-color-scheme: dark)');

function currentTheme() {
  return document.documentElement.dataset.theme ?? (darkQuery.matches ? 'dark' : 'light');
}

function toggleTheme() {
  const next = currentTheme() === 'dark' ? 'light' : 'dark';
  document.documentElement.dataset.theme = next;
  storage.setTheme(next);
  ui.updateThemeToggle(next);
}

// ---------- Eventos ----------

const actions = {
  start: () => (state.player ? openLevelSelect() : openPlayerForm()),
  leaderboard: openLeaderboard,
  'leaderboard-back': () => go(state.leaderboardReturn),
  home: () => go('HOME'),
  'not-me': notMe,
  'change-player': openPlayerForm,
  'select-level': (button) => startRound(button.dataset.level),
  answer: (button) => state.round?.answer(button.dataset.value === 'true'),
  review: () => {
    ui.renderReview(state.result.results);
    go('REVIEW');
  },
  'back-result': () => go('RESULT'),
  'play-again': () => startRound(state.level),
  'change-level': openLevelSelect,
  retry: () => state.retry?.(),
  theme: toggleTheme,
};

document.addEventListener('click', (event) => {
  const target = event.target.closest('[data-action], [data-level-tab]');
  if (!target) return;
  if (target.dataset.levelTab) loadLeaderboard(target.dataset.levelTab);
  else actions[target.dataset.action]?.(target);
});

// Atalhos da pergunta: V / ← = Verdadeiro; F / → = Falso.
document.addEventListener('keydown', (event) => {
  if (state.current !== 'QUESTION' || event.repeat || event.altKey || event.ctrlKey || event.metaKey) return;
  const key = event.key.toLowerCase();
  if (key === 'v' || event.key === 'ArrowLeft') {
    event.preventDefault();
    state.round?.answer(true);
  } else if (key === 'f' || event.key === 'ArrowRight') {
    event.preventDefault();
    state.round?.answer(false);
  }
});

document.getElementById('player-form').addEventListener('submit', submitPlayerForm);
document.getElementById('leaderboard-tabs').addEventListener('keydown', onTabKeydown);
darkQuery.addEventListener('change', () => ui.updateThemeToggle(currentTheme()));

ui.updateThemeToggle(currentTheme());
go('HOME', { focus: false });
