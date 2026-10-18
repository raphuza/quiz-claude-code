// Timer de contagem regressiva baseado em requestAnimationFrame + performance.now().
// Um setTimeout de segurança garante a expiração mesmo se o rAF for pausado (aba em segundo plano).

/**
 * @param {object} opts
 * @param {number} opts.durationMs
 * @param {(remainingMs: number) => void} [opts.onTick]      chamado a cada frame
 * @param {(seconds: number) => void} [opts.onAnnounce]      chamado uma vez ao cruzar cada marco
 * @param {() => void} [opts.onExpire]
 * @param {number[]} [opts.announceAt]                       marcos em segundos, decrescentes
 * @returns {{ stop: () => number }} stop() para o timer e devolve o tempo decorrido em ms
 */
export function startTimer({ durationMs, onTick, onAnnounce, onExpire, announceAt = [10, 5] }) {
  const startedAt = performance.now();
  const pending = [...announceAt];
  let stopped = false;
  let stoppedElapsed = 0;
  let frame = 0;

  const elapsed = () => performance.now() - startedAt;
  const fallback = setTimeout(expire, durationMs + 50);

  function tick() {
    if (stopped) return;
    const remaining = Math.max(0, durationMs - elapsed());
    onTick?.(remaining);

    // Se vários marcos foram cruzados de uma vez (aba oculta), anuncia só o mais recente.
    let crossed = null;
    while (pending.length && remaining <= pending[0] * 1000) crossed = pending.shift();
    if (crossed !== null && remaining > 0) onAnnounce?.(crossed);

    if (remaining <= 0) expire();
    else frame = requestAnimationFrame(tick);
  }

  function expire() {
    if (stopped) return;
    onTick?.(0);
    onExpire?.();
  }

  function stop() {
    if (!stopped) {
      stopped = true;
      stoppedElapsed = elapsed();
      cancelAnimationFrame(frame);
      clearTimeout(fallback);
    }
    return Math.round(stoppedElapsed);
  }

  frame = requestAnimationFrame(tick);
  return { stop };
}
