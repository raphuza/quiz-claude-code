// Renderização das telas. Dados dinâmicos entram somente via textContent /
// nós de texto — nunca innerHTML com dados.

export const LEVELS = {
  iniciante: { label: 'Iniciante' },
  intermediario: { label: 'Intermediário' },
  avancado: { label: 'Avançado' },
};

const $ = (id) => document.getElementById(id);

/** Cria um elemento. attrs: class, text, on<evento> ou atributos comuns. */
export function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value == null || value === false) continue;
    if (key === 'class') node.className = value;
    else if (key === 'text') node.textContent = value;
    else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value === true ? '' : String(value));
  }
  node.append(...children.flat().filter((child) => child != null));
  return node;
}

/** Converte trechos entre crases em <code>, sem interpretar HTML. */
export function richText(text) {
  return String(text ?? '')
    .split('`')
    .map((part, i) => (i % 2 ? el('code', { text: part }) : part))
    .filter((part) => part !== '');
}

function setRich(node, text) {
  node.replaceChildren(...richText(text));
}

export function formatSeconds(ms) {
  const seconds = (ms ?? 0) / 1000;
  return `${seconds.toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} s`;
}

function formatDate(iso) {
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleDateString('pt-BR');
}

function answerLabel(value) {
  if (value === true) return 'Verdadeiro';
  if (value === false) return 'Falso';
  return 'Tempo esgotado';
}

// ---------- Navegação e anúncios ----------

export function showScreen(name, { focus = true } = {}) {
  for (const section of document.querySelectorAll('[data-screen]')) {
    section.hidden = section.dataset.screen !== name;
  }
  window.scrollTo(0, 0);
  if (focus) document.querySelector(`[data-screen="${name}"] [data-autofocus]`)?.focus();
}

let announceTimeout = 0;
export function announce(message) {
  const region = $('announcer');
  region.textContent = '';
  clearTimeout(announceTimeout);
  // Pequeno atraso para leitores de tela perceberem a mudança mesmo com texto repetido.
  announceTimeout = setTimeout(() => { region.textContent = message; }, 50);
}

export function updateThemeToggle(theme) {
  const toDark = theme !== 'dark';
  $('theme-toggle').setAttribute('aria-label', toDark ? 'Ativar tema escuro' : 'Ativar tema claro');
  $('theme-toggle-icon').textContent = toDark ? '☾' : '☀';
}

// ---------- Jogador ----------

const FIELDS = {
  name: { input: 'player-name', error: 'player-name-error' },
  email: { input: 'player-email', error: 'player-email-error' },
  consent: { input: 'player-consent', error: 'player-consent-error' },
};

export function fillPlayerForm(player) {
  $('player-name').value = player?.name ?? '';
  $('player-email').value = player?.email ?? '';
  $('player-consent').checked = false;
  $('not-me').hidden = !player;
  showFormErrors({}, { focus: false });
}

export function readPlayerForm() {
  return {
    name: $('player-name').value,
    email: $('player-email').value,
    consent: $('player-consent').checked,
  };
}

/** errors: { name?, email?, consent? } → mensagens. Foca o primeiro campo inválido. */
export function showFormErrors(errors, { focus = true } = {}) {
  let first = null;
  for (const [field, ids] of Object.entries(FIELDS)) {
    const message = errors[field] ?? '';
    const input = $(ids.input);
    $(ids.error).textContent = message;
    if (message) {
      input.setAttribute('aria-invalid', 'true');
      first ??= input;
    } else {
      input.removeAttribute('aria-invalid');
    }
  }
  if (focus) first?.focus();
}

export function focusPlayerName() {
  $('player-name').focus();
}

export function renderLevelSelect(playerName) {
  $('level-greeting').textContent = `Olá, ${playerName}!`;
}

export function setLoading(message) {
  $('loading-text').textContent = message;
}

// ---------- Pergunta ----------

let lastSecond = null;

export function renderQuestion({ number, total, statement, levelLabel }) {
  $('question-level').textContent = levelLabel;
  $('question-progress').textContent = `Pergunta ${number} de ${total}`;
  setRich($('question-statement'), statement);
  $('answer-feedback').textContent = '';
  for (const button of document.querySelectorAll('.answer-btn')) {
    button.disabled = false;
    button.classList.remove('is-selected');
  }
  const card = $('question-card');
  card.classList.remove('is-entering');
  void card.offsetWidth; // reinicia a animação de entrada
  card.classList.add('is-entering');
  lastSecond = null;
  $('question-statement').focus();
}

export function updateTimer(remainingMs, durationMs) {
  $('timer-bar').style.transform = `scaleX(${remainingMs / durationMs})`;
  const second = Math.ceil(remainingMs / 1000);
  if (second !== lastSecond) {
    lastSecond = second;
    $('timer-count').textContent = `${second}s`;
    $('timer').classList.toggle('is-alert', remainingMs <= 5000);
  }
}

/** Feedback neutro: nunca indica se a resposta está certa. value null = tempo esgotado. */
export function showAnswerFeedback(value) {
  for (const button of document.querySelectorAll('.answer-btn')) {
    button.disabled = true;
    button.classList.toggle('is-selected', value !== null && button.dataset.value === String(value));
  }
  $('answer-feedback').textContent = value === null ? 'Tempo esgotado' : 'Resposta registrada';
}

// ---------- Resultado ----------

function resultMessage(correct) {
  if (correct === 5) return 'Mandou muito bem!';
  if (correct >= 3) return 'Bom resultado, quase lá!';
  return 'Que tal revisar e tentar de novo?';
}

export function renderResult(result, levelLabel) {
  $('result-level').textContent = `Nível ${levelLabel}`;
  $('result-title').textContent = resultMessage(result.correct_count);
  $('result-score').textContent = String(result.score);
  $('result-correct').textContent = `${result.correct_count} de 5`;
  $('result-time').textContent = formatSeconds(result.total_time_ms);

  let rankLine = '';
  if (result.best_score != null) {
    rankLine = result.ranked && result.score === result.best_score
      ? `Você está em ${result.rank}º no ranking ${levelLabel}.`
      : `Sua melhor pontuação continua sendo ${result.best_score} (${result.rank}º no ranking ${levelLabel}).`;
  }
  $('result-rank').textContent = rankLine;

  const note = $('result-note');
  note.hidden = result.ranked;
  note.textContent = result.ranked ? '' : 'Esta rodada não entrou no ranking porque o tempo registrado não pôde ser validado.';
}

// ---------- Revisão ----------

function safeDocUrl(url) {
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' ? parsed.href : null;
  } catch {
    return null;
  }
}

export function renderReview(results) {
  const items = results.map((item, i) => {
    const href = safeDocUrl(item.doc_url);
    return el('li', { class: `review-item${item.is_correct ? ' is-correct' : ''}` },
      el('p', { class: 'review-head' },
        el('span', { class: 'review-badge', text: item.is_correct ? '✓ Acertou' : '✗ Errou' }),
        el('span', { class: 'review-number', text: `Pergunta ${i + 1}` }),
        el('span', { class: 'review-points', text: `${item.points} pts` }),
      ),
      el('p', { class: 'review-statement' }, richText(item.statement)),
      el('dl', { class: 'review-answers' },
        el('dt', { text: 'Sua resposta' }), el('dd', { text: answerLabel(item.answer) }),
        el('dt', { text: 'Resposta correta' }), el('dd', { text: answerLabel(item.correct_answer) }),
      ),
      el('p', { class: 'review-explanation' }, richText(item.explanation)),
      href && el('a', { class: 'review-link', href, target: '_blank', rel: 'noopener noreferrer' },
        'Saiba mais', el('span', { class: 'visually-hidden', text: ' (abre em nova aba)' })),
    );
  });
  $('review-list').replaceChildren(...items);
}

// ---------- Ranking ----------

export function selectLeaderboardTab(level) {
  for (const tab of document.querySelectorAll('[data-level-tab]')) {
    const selected = tab.dataset.levelTab === level;
    tab.setAttribute('aria-selected', String(selected));
    tab.tabIndex = selected ? 0 : -1;
  }
  $('leaderboard-panel').setAttribute('aria-labelledby', `tab-${level}`);
}

export function setLeaderboardStatus(message) {
  $('leaderboard-status').textContent = message;
  $('leaderboard-table-wrap').hidden = true;
  $('leaderboard-me').hidden = true;
}

/** me: linha do jogador atual neste nível (is_me, vinda do servidor) ou null. */
export function renderLeaderboard(rows, me, levelLabel) {
  if (!rows.length) {
    setLeaderboardStatus('Ninguém pontuou neste nível ainda. Seja o primeiro!');
    return;
  }
  $('leaderboard-status').textContent = '';
  $('leaderboard-caption').textContent = `Top ${rows.length} do nível ${levelLabel}`;

  let meInTable = false;
  const trs = rows.map((row) => {
    const isMe = row.is_me;
    meInTable ||= isMe;
    return el('tr', { class: isMe ? 'is-me' : null, 'aria-current': isMe ? 'true' : null },
      el('td', { text: `${row.position}º` }),
      el('td', { text: isMe ? `${row.name} (você)` : row.name }),
      el('td', { class: 'num', text: String(row.score) }),
      el('td', { class: 'num', text: `${row.correct_count}/5` }),
      el('td', { class: 'num', text: formatSeconds(row.total_time_ms) }),
      el('td', { text: formatDate(row.finished_at) }),
    );
  });
  $('leaderboard-body').replaceChildren(...trs);
  $('leaderboard-table-wrap').hidden = false;

  const meLine = $('leaderboard-me');
  meLine.hidden = me == null || meInTable;
  meLine.textContent = meLine.hidden ? '' : `Sua posição no ranking ${levelLabel}: ${me.position}º`;
}

// ---------- Erro ----------

export function renderError(message) {
  $('error-message').textContent = message;
}
