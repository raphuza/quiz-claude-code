// Cliente Supabase e chamadas RPC. O front nunca usa supabase.from(...):
// apenas start_quiz, submit_quiz e get_leaderboard.

import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';

const SUPABASE_CDN = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

// Códigos levantados pelas RPCs (`raise exception '<CODIGO>'`) → mensagens PT-BR.
const ERROR_MESSAGES = {
  CONSENT_REQUIRED: 'Você precisa marcar o consentimento para jogar.',
  INVALID_NAME: 'Informe um nome entre 2 e 40 caracteres.',
  BLOCKED_NAME: 'Esse nome não é permitido no ranking. Escolha outro.',
  INVALID_EMAIL: 'Informe um e-mail válido.',
  RATE_LIMIT: 'Você atingiu o limite de 30 rodadas por hora. Tente novamente mais tarde.',
  NOT_ENOUGH_QUESTIONS: 'Este nível ainda não tem perguntas suficientes. Escolha outro nível.',
  SESSION_NOT_FOUND: 'Não encontramos sua rodada. Vamos começar uma nova.',
  INVALID_ANSWERS: 'Não foi possível validar suas respostas. Vamos começar uma nova rodada.',
};

const GENERIC_MESSAGE = 'Não foi possível falar com o servidor. Verifique sua conexão e tente novamente.';

export class ApiError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
  }
}

let clientPromise = null;

function getClient() {
  if (SUPABASE_URL.includes('SEU-PROJETO') || SUPABASE_ANON_KEY.includes('SUA-CHAVE')) {
    return Promise.reject(new ApiError('NOT_CONFIGURED', 'O quiz ainda não foi configurado: preencha js/config.js com os dados do Supabase.'));
  }
  // Import dinâmico: se o CDN falhar, o app continua de pé e mostra a tela de erro.
  clientPromise ??= import(SUPABASE_CDN)
    .then(({ createClient }) => createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    }))
    .catch((err) => {
      clientPromise = null;
      throw err;
    });
  return clientPromise;
}

async function rpc(fn, params) {
  let result;
  try {
    const client = await getClient();
    result = await client.rpc(fn, params);
  } catch (err) {
    if (err instanceof ApiError) throw err;
    throw new ApiError('NETWORK', GENERIC_MESSAGE);
  }
  if (result.error) {
    const code = result.error.message;
    if (Object.hasOwn(ERROR_MESSAGES, code)) throw new ApiError(code, ERROR_MESSAGES[code]);
    throw new ApiError('UNKNOWN', GENERIC_MESSAGE);
  }
  return result.data;
}

/** @returns {Promise<{session_id: string, questions: {id: number, statement: string}[]}>} */
export function startQuiz({ name, email, level }) {
  return rpc('start_quiz', { p_name: name, p_email: email, p_level: level, p_consent: true });
}

/** @param {{question_id: number, answer: boolean|null, time_ms: number}[]} answers */
export function submitQuiz(sessionId, answers) {
  return rpc('submit_quiz', { p_session_id: sessionId, p_answers: answers });
}

const LEADERBOARD_LIMIT = 10;

/**
 * sessionId: última sessão do jogador neste navegador (ou null). O servidor marca a linha dele
 * com is_me e a anexa mesmo fora do Top 10.
 * @returns {Promise<{rows: LeaderboardRow[], me: LeaderboardRow|null}>} rows = Top 10; me = linha do jogador.
 * @typedef {{position: number, name: string, score: number, correct_count: number, total_time_ms: number, finished_at: string, is_me: boolean}} LeaderboardRow
 */
export async function getLeaderboard(level, sessionId = null) {
  const data = (await rpc('get_leaderboard', { p_level: level, p_limit: LEADERBOARD_LIMIT, p_session_id: sessionId })) ?? [];
  return {
    rows: data.filter((row) => row.position <= LEADERBOARD_LIMIT),
    me: data.find((row) => row.is_me) ?? null,
  };
}
