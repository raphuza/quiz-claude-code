// Fluxo de uma rodada: exibe as perguntas em sequência, controla o timer e coleta
// as respostas. Não calcula pontuação — isso é feito somente no servidor.

import { startTimer } from './timer.js';
import * as ui from './ui.js';

export const QUESTION_TIME_MS = 20000;
const FEEDBACK_MS = 400;

/**
 * @param {object} opts
 * @param {string} opts.sessionId
 * @param {{id: number, statement: string}[]} opts.questions
 * @param {string} opts.levelLabel
 * @param {(payload: {sessionId: string, answers: object[]}) => void} opts.onComplete
 */
export function createRound({ sessionId, questions, levelLabel, onComplete }) {
  const answers = [];
  let index = 0;
  let timer = null;
  let locked = true;

  function showQuestion() {
    const question = questions[index];
    ui.renderQuestion({ number: index + 1, total: questions.length, statement: question.statement, levelLabel });
    locked = false;
    timer = startTimer({
      durationMs: QUESTION_TIME_MS,
      onTick: (remaining) => ui.updateTimer(remaining, QUESTION_TIME_MS),
      onAnnounce: (seconds) => ui.announce(`${seconds} segundos restantes`),
      onExpire: () => record(null),
    });
  }

  /** value: true | false | null (tempo esgotado). Ignora respostas repetidas. */
  function record(value) {
    if (locked) return;
    locked = true;
    const timeMs = timer.stop();
    answers.push({ question_id: questions[index].id, answer: value, time_ms: timeMs });
    ui.showAnswerFeedback(value);
    setTimeout(next, FEEDBACK_MS);
  }

  function next() {
    index += 1;
    if (index < questions.length) showQuestion();
    else onComplete({ sessionId, answers });
  }

  return {
    start: showQuestion,
    answer: (value) => record(value),
  };
}
