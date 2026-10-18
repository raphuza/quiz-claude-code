// Preferências locais (jogador e tema). Todo acesso ao localStorage é protegido
// por try/catch: em modo privado ou com armazenamento bloqueado o app segue funcionando.

const PLAYER_KEY = 'quiz-cc:player';
const THEME_KEY = 'quiz-cc:theme'; // mesma chave usada em js/theme-init.js

function read(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function write(key, value) {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch {
    // Ignora: a preferência só não será lembrada.
  }
}

export function getPlayer() {
  const raw = read(PLAYER_KEY);
  if (!raw) return null;
  try {
    const player = JSON.parse(raw);
    if (typeof player?.name === 'string' && typeof player?.email === 'string') {
      return { name: player.name, email: player.email };
    }
  } catch {
    // Valor corrompido: trata como ausente.
  }
  return null;
}

export function savePlayer({ name, email }) {
  write(PLAYER_KEY, JSON.stringify({ name, email }));
}

export function clearPlayer() {
  write(PLAYER_KEY, null);
}

export function getTheme() {
  const theme = read(THEME_KEY);
  return theme === 'light' || theme === 'dark' ? theme : null;
}

export function setTheme(theme) {
  write(THEME_KEY, theme);
}
