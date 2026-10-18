// Aplica o tema salvo antes da primeira pintura (evita flash de tema).
// Script clássico (não-módulo) carregado no <head>; sem tema salvo, o CSS segue prefers-color-scheme.
// A chave precisa ser a mesma de js/storage.js.
(function () {
  try {
    var theme = localStorage.getItem('quiz-cc:theme');
    if (theme === 'light' || theme === 'dark') {
      document.documentElement.setAttribute('data-theme', theme);
    }
  } catch (e) {
    // localStorage indisponível (modo privado, bloqueado): segue o tema do sistema.
  }
})();
