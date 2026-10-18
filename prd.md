# PRD — Quiz Claude Code (Verdadeiro ou Falso)

> Documento de requisitos de produto destinado a ser consumido pelo Claude Code para construir o projeto.
> Versão 1.0 · 2026-10-18 · Status: aprovado no brainstorm

---

## 1. Resumo

Aplicação web educacional em **PT-BR** com um quiz de **Verdadeiro ou Falso** sobre o **Claude Code**. O usuário informa nome e e-mail, escolhe um nível (**Iniciante**, **Intermediário** ou **Avançado**) e responde **5 perguntas sorteadas** de um banco de 15 por nível, com **20 segundos por pergunta**. A pontuação considera acerto e rapidez. Ao final, o jogador vê o resultado, a **revisão completa** com explicações e o **ranking global Top 10 do nível**.

Front-end em **HTML/CSS/JavaScript puro** (sem build), backend no **Supabase** (Postgres + RPC), deploy estático na **Vercel**.

---

## 2. Contexto e objetivos de negócio

### 2.1 Problema
Times e alunos que estão adotando o Claude Code não têm uma forma rápida e divertida de verificar o que já sabem e onde estão as lacunas, desde conceitos de negócio (o que é, para que serve) até recursos avançados (hooks, subagentes, MCP, permissões).

### 2.2 Objetivos
| # | Objetivo | Como medir |
|---|----------|------------|
| O1 | Reforçar o aprendizado sobre Claude Code em treinamentos e cursos | % de rodadas concluídas; jogadores que repetem o nível |
| O2 | Identificar lacunas de conhecimento da turma | Taxa de erro por pergunta (view `question_stats`) |
| O3 | Engajar por meio de competição saudável | Nº de jogadores únicos no ranking por nível |
| O4 | Incentivar a progressão Iniciante → Avançado | % de jogadores que jogam mais de um nível |

### 2.3 Público-alvo (personas)
- **Gestor/negócios (Iniciante):** quer entender o que o Claude Code é, o que faz, quem pode usar e como a empresa o adota. Sem conhecimento técnico.
- **Desenvolvedor iniciando (Intermediário):** já usou o Claude Code; conhece comandos básicos, CLAUDE.md, plan mode e MCP superficialmente.
- **Power user/tech lead (Avançado):** configura hooks, subagentes, permissões, settings gerenciados, SDK e CI.

### 2.4 KPIs de sucesso (primeiros 30 dias após lançamento)
- Taxa de conclusão de rodada ≥ 80% (rodadas finalizadas / iniciadas).
- Tempo médio de rodada entre 1 e 2 minutos.
- Pelo menos 1 pergunta por nível com taxa de erro > 50% identificada e endereçada no conteúdo do curso.

---

## 3. Escopo

### 3.1 Dentro do escopo (MVP)
- Tela inicial com apresentação do quiz.
- Cadastro leve: nome, e-mail e consentimento LGPD (sem senha/login).
- Seleção de nível (3 níveis).
- Rodada de 5 perguntas V/F sorteadas e embaralhadas, com timer de 20s por pergunta.
- Pontuação calculada **no servidor** (anti-fraude básico).
- Tela de resultado com pontuação, acertos e posição no ranking.
- Tela de revisão: todas as perguntas da rodada, resposta do jogador, resposta correta, explicação e link para a documentação oficial.
- Ranking global Top 10 por nível (exibe apenas o nome, nunca o e-mail).
- Tema visual inspirado no Claude, com modo claro e escuro.
- Responsivo (mobile first) e acessível via teclado.

### 3.2 Fora do escopo (MVP)
- Login/OAuth e senhas.
- Painel administrativo (conteúdo é gerenciado por SQL/Supabase Studio).
- Explicação imediata após cada resposta (a explicação aparece somente na revisão final).
- Internacionalização (apenas PT-BR).
- Ranking semanal/geral e compartilhamento em redes sociais.
- Modo offline.

---

## 4. Requisitos funcionais

### RF01 — Tela inicial
- Exibe título, breve descrição ("Teste seus conhecimentos sobre Claude Code em 5 perguntas de Verdadeiro ou Falso"), regras resumidas (5 perguntas, 20s cada, bônus por rapidez) e botões **Começar** e **Ver ranking**.

### RF02 — Identificação do jogador
- Campos: **Nome** (obrigatório, 2–40 caracteres, exibido no ranking) e **E-mail** (obrigatório, formato válido, nunca exibido publicamente).
- Checkbox obrigatório de consentimento: *"Concordo que meu nome seja exibido no ranking público e que meu e-mail seja armazenado para identificação no quiz, conforme a LGPD."*
- Nome e e-mail ficam salvos em `localStorage` para preencher automaticamente na próxima visita (com opção "Não sou eu" para limpar).
- O e-mail é normalizado (trim + lowercase) e identifica o jogador de forma única. Se o mesmo e-mail voltar com outro nome, o nome é atualizado.

### RF03 — Seleção de nível
- Três cards: **Iniciante** (conceitos e negócios), **Intermediário** (uso no dia a dia), **Avançado** (configuração e extensibilidade), cada um com descrição curta.

### RF04 — Início da rodada
- O front chama a RPC `start_quiz`, que cria a sessão e devolve 5 perguntas aleatórias e ativas do nível **sem a resposta correta**.
- Em caso de erro de rede, exibe mensagem amigável com botão **Tentar novamente**.

### RF05 — Pergunta
- Exibe: progresso ("Pergunta 2 de 5"), enunciado, barra/contador do timer (20s), pontuação parcial estimada não é exibida (pontuação é calculada no servidor).
- Botões grandes **Verdadeiro** e **Falso**.
- Atalhos de teclado: `V` ou `←` = Verdadeiro; `F` ou `→` = Falso.
- Ao responder: botão escolhido fica destacado por ~400 ms com feedback neutro ("Resposta registrada") — **sem revelar se acertou** — e avança para a próxima pergunta.
- Se o tempo acabar: a resposta é registrada como `null` (sem resposta, conta como erro) e avança automaticamente.
- O front registra `time_ms` (tempo gasto em cada pergunta) usando `performance.now()`.

### RF06 — Envio e pontuação
- Após a 5ª pergunta, o front chama a RPC `submit_quiz` com as respostas.
- O servidor valida e calcula (ver §6.4) e devolve: pontuação, acertos, tempo total, resultado detalhado por pergunta e posição no ranking do nível.

### RF07 — Tela de resultado
- Mostra: pontuação (ex.: `612 / 750`), acertos (`4 de 5`), tempo total, mensagem por faixa de desempenho e posição no ranking (`Você está em 7º no ranking Intermediário` ou `Sua melhor pontuação continua sendo X`).
- Faixas de mensagem: 5 acertos "Mandou muito bem!"; 3–4 "Bom resultado, quase lá!"; 0–2 "Que tal revisar e tentar de novo?".
- Botões: **Ver revisão**, **Ver ranking**, **Jogar novamente** (mesmo nível), **Trocar nível**.

### RF08 — Revisão
- Lista as 5 perguntas com: enunciado, resposta do jogador (ou "Tempo esgotado"), resposta correta, ícone ✓/✗, explicação e link "Saiba mais" para a documentação (abre em nova aba).

### RF09 — Ranking
- Abas por nível (Iniciante / Intermediário / Avançado).
- Top 10 com: posição, nome, melhor pontuação, acertos, tempo total e data.
- Considera **somente a melhor pontuação de cada jogador** por nível.
- Desempate: maior pontuação → menor tempo total → quem alcançou primeiro.
- Destaca a linha do jogador atual, se estiver no Top 10; se não estiver, mostra sua posição abaixo da tabela.

### RF10 — Tema e preferências
- Alternância claro/escuro, respeitando `prefers-color-scheme` por padrão e salvando a escolha em `localStorage`.

---

## 5. Requisitos não funcionais

| Categoria | Requisito |
|-----------|-----------|
| Performance | Primeira carga < 1,5 s em 4G; página total < 300 KB (sem contar SDK via CDN). |
| Compatibilidade | Últimas 2 versões de Chrome, Edge, Firefox e Safari; iOS/Android. |
| Responsividade | Mobile first; layout funcional de 320 px até desktop; sem scroll horizontal. |
| Acessibilidade | WCAG 2.1 AA: contraste, foco visível, navegação por teclado, `aria-live="polite"` para o timer (anunciar apenas em 10s e 5s), botões com rótulos claros. Respeitar `prefers-reduced-motion`. |
| Segurança | Tabelas com RLS sem acesso direto do `anon`; acesso somente via RPC `security definer`; resposta correta nunca enviada ao cliente antes do envio; pontuação calculada no servidor; escapar todo conteúdo dinâmico ao renderizar (usar `textContent`, nunca `innerHTML` com dados). |
| Privacidade (LGPD) | E-mail nunca retornado por nenhuma RPC pública; consentimento registrado com data/hora; política de retenção definida (ver §11). |
| Manutenibilidade | Código em módulos ES (`type="module"`), sem frameworks e sem etapa de build; perguntas gerenciadas apenas no banco. |

---

## 6. Especificação técnica

### 6.1 Arquitetura

```
[Navegador: HTML/CSS/JS ES Modules]
        │  supabase-js v2 (CDN) — chave anon (publishable)
        ▼
[Supabase]
  ├─ RPC (security definer): start_quiz, submit_quiz, get_leaderboard
  └─ Postgres: questions, players, quiz_sessions, session_answers (RLS ativo, sem policies para anon)

[Deploy] Vercel ou Netlify — site estático (diretório raiz do projeto)
```

### 6.2 Estrutura de pastas

```
quiz-claude-code/
├── index.html                # SPA com as seções/telas
├── css/
│   └── styles.css            # tokens de cor, temas claro/escuro, layout
├── js/
│   ├── main.js               # bootstrap, roteamento simples entre telas (máquina de estados)
│   ├── api.js                # cliente Supabase e chamadas RPC
│   ├── quiz.js               # fluxo da rodada (perguntas, respostas, envio)
│   ├── timer.js              # timer de 20s baseado em requestAnimationFrame/performance.now
│   ├── ui.js                 # renderização das telas (usar textContent)
│   ├── storage.js            # localStorage com try/catch (jogador, tema)
│   ├── config.js             # SUPABASE_URL e SUPABASE_ANON_KEY (gerado a partir do example)
│   └── config.example.js
├── supabase/
│   ├── migrations/
│   │   └── 001_schema.sql    # tabelas, índices, RLS, funções, views
│   └── seed.sql              # banco inicial de 45 perguntas (Apêndice A)
├── assets/
│   └── favicon.svg
├── README.md                 # setup local, Supabase, deploy
└── vercel.json / netlify.toml (opcional: headers de segurança)
```

- Supabase SDK via ESM CDN: `import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm'`.
- A chave `anon` é pública por design; a segurança depende do RLS e das RPCs. `config.js` pode ser versionado ou gerado no deploy; documentar no README.
- Desenvolvimento local: qualquer servidor estático (ex.: `npx serve .`), pois módulos ES não funcionam via `file://`.

### 6.3 Máquina de estados do front

```
HOME → PLAYER_FORM → LEVEL_SELECT → LOADING → QUESTION (x5) → SUBMITTING → RESULT
                                                                         ├→ REVIEW
                                                                         └→ LEADERBOARD
HOME → LEADERBOARD
Qualquer estado de rede → ERROR (com "Tentar novamente")
```

### 6.4 Regras de pontuação (executadas no servidor)
- Acerto: **100 pontos**.
- Bônus de rapidez (somente em acertos): `floor(50 * (20000 - time_ms) / 20000)`, com `time_ms` limitado a `[0, 20000]`.
- Erro ou tempo esgotado (`answer = null`): **0 pontos**.
- Máximo por rodada: **750 pontos** (5 × 150).
- Validações anti-fraude em `submit_quiz`:
  - Sessão existe, não foi finalizada e tem as mesmas 5 `question_ids` enviadas.
  - `time_ms` entre 300 e 20.500 (tolerância de rede); valores fora disso são normalizados (< 300 → 300; > 20.500 → resposta tratada como tempo esgotado).
  - Tempo real decorrido no servidor (`now() - started_at`) ≥ soma dos `time_ms` − 2 s; se violar, a sessão é registrada mas marcada `ranked = false`.
  - Sessão enviada mais de 5 minutos após `started_at` → `ranked = false`.
  - Limite de 30 sessões por e-mail por hora em `start_quiz` (retorna erro amigável).

### 6.5 Modelo de dados (Postgres/Supabase)

```sql
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

create index on quiz_sessions (level, score desc, total_time_ms asc, finished_at asc) where finished_at is not null and ranked;
create index on quiz_sessions (player_id, started_at);
```

- **RLS:** `alter table ... enable row level security` em todas as tabelas, **sem** policies para `anon`/`authenticated`.
- **Funções** criadas com `security definer` e `set search_path = public`; `grant execute ... to anon`.

### 6.6 Contratos das RPCs

**`start_quiz(p_name text, p_email text, p_level quiz_level, p_consent boolean)`**
- Valida entradas (consentimento = true, e-mail com regex simples, nome 2–40 após trim).
- Upsert em `players` por e-mail (atualiza nome e `updated_at`).
- Aplica o rate limit.
- Sorteia 5 perguntas ativas do nível (`order by random() limit 5`), cria `quiz_sessions`.
- Retorno:
```json
{ "session_id": "uuid", "questions": [ { "id": 12, "statement": "..." } ] }
```

**`submit_quiz(p_session_id uuid, p_answers jsonb)`**
- `p_answers`: `[ { "question_id": 12, "answer": true | false | null, "time_ms": 8350 } ]` (5 itens).
- Valida, calcula pontos, grava `session_answers`, finaliza a sessão.
- Retorno:
```json
{
  "score": 612, "correct_count": 4, "total_time_ms": 41230, "ranked": true,
  "rank": 7, "best_score": 650,
  "results": [ { "question_id": 12, "statement": "...", "answer": true, "correct_answer": false,
                 "is_correct": false, "points": 0, "explanation": "...", "doc_url": "https://..." } ]
}
```
- `rank` = posição do jogador no ranking do nível considerando sua melhor pontuação.

**`get_leaderboard(p_level quiz_level, p_limit int default 10)`**
- Melhor sessão `ranked` e finalizada por jogador no nível, ordenada por `score desc, total_time_ms asc, finished_at asc`.
- Retorno: `[ { "position": 1, "name": "Ana", "score": 735, "correct_count": 5, "total_time_ms": 21000, "finished_at": "..." } ]` — **sem e-mail nem player_id**.

**View de análise (somente para o Studio, sem grant ao anon): `question_stats`**
- Por pergunta: nível, enunciado, total de respostas, % de acerto, % de tempo esgotado, tempo médio.

### 6.7 Identidade visual
- Inspirada no Claude: tons **terracota** (acento, ~`#D97757`), **creme** (fundo claro, ~`#F5F0E8`), **grafite** (texto/fundo escuro, ~`#1F1E1D`).
- Cores definidas como CSS custom properties em `:root`, redefinidas em `@media (prefers-color-scheme: dark)` e em `[data-theme="dark"]` / `[data-theme="light"]`.
- Tipografia: sans-serif limpa para textos (ex.: Inter, via Google Fonts ou system font stack); monoespaçada para detalhes de "terminal" (rótulos de nível, timer, nomes de comandos como `/init`).
- Botões Verdadeiro/Falso grandes (mín. 48 px de altura), com ícones ✓ / ✗ além da cor (não depender apenas da cor).
- Timer: barra que encolhe; muda para cor de alerta nos últimos 5s.
- Animações sutis (transição entre perguntas ≤ 250 ms), desativadas com `prefers-reduced-motion`.

### 6.8 Deploy e ambiente
1. Criar projeto no Supabase; executar `supabase/migrations/001_schema.sql` e `supabase/seed.sql` (SQL Editor ou Supabase CLI).
2. Copiar `js/config.example.js` para `js/config.js` com `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
3. Deploy estático na Vercel/Netlify apontando para a raiz (sem build command).
4. Headers recomendados: `Content-Security-Policy` permitindo `cdn.jsdelivr.net`, `fonts.googleapis.com`, `fonts.gstatic.com` e o domínio `*.supabase.co`; `X-Content-Type-Options: nosniff`; `Referrer-Policy: strict-origin-when-cross-origin`.

---

## 7. Critérios de aceitação

- [ ] É impossível iniciar a rodada sem nome válido, e-mail válido e consentimento marcado.
- [ ] Cada rodada traz 5 perguntas distintas do nível escolhido, em ordem aleatória.
- [ ] Nenhuma resposta correta ou explicação aparece na rede (DevTools) antes do `submit_quiz`.
- [ ] O timer chega a 0 em 20s, registra "tempo esgotado" e avança automaticamente.
- [ ] Atalhos `V`/`F`/`←`/`→` funcionam; não é possível responder duas vezes a mesma pergunta.
- [ ] A pontuação exibida é a calculada pelo servidor e segue a fórmula do §6.4.
- [ ] A revisão mostra as 5 perguntas com resposta do jogador, resposta correta, explicação e link.
- [ ] O ranking mostra no máximo 10 jogadores por nível, apenas a melhor pontuação de cada um, sem e-mails.
- [ ] Consultas diretas às tabelas com a chave anon (`supabase.from('players').select()`) retornam vazio/erro.
- [ ] Layout funciona em 320 px, sem scroll horizontal; modo claro/escuro funcionam.
- [ ] Falha de rede exibe mensagem amigável com opção de tentar novamente.
- [ ] Lighthouse: Acessibilidade ≥ 90, Performance ≥ 90.

---

## 8. Plano de entrega (milestones)

| Fase | Entregas |
|------|----------|
| M1 — Backend | Schema, RLS, RPCs, seed das 45 perguntas, testes manuais das RPCs no SQL Editor |
| M2 — Front base | Estrutura de arquivos, tema/tokens, telas Home, Cadastro, Seleção de nível |
| M3 — Fluxo do quiz | Pergunta + timer + atalhos, envio, Resultado, Revisão |
| M4 — Ranking | Tela de ranking com abas e destaque do jogador |
| M5 — Polimento | Acessibilidade, responsividade, estados de erro/carregamento, README, deploy |

---

## 9. Riscos e mitigações

| Risco | Mitigação |
|-------|-----------|
| Conteúdo das perguntas desatualizado (o Claude Code evolui rápido) | Campo `active` para desativar perguntas; revisar o banco a cada release relevante; `doc_url` em toda pergunta |
| Fraude no ranking (scripts) | Pontuação no servidor, validação de tempo, rate limit, flag `ranked` |
| E-mails falsos/duplicados | Aceito no MVP (sem verificação); e-mail apenas como identificador |
| Exposição de dados pessoais | RLS sem policies + RPCs que nunca retornam e-mail |
| Nomes ofensivos no ranking | Lista simples de palavras bloqueadas na RPC; remoção manual pelo Studio |

---

## 10. Métricas e analytics
- Usar os próprios dados do Supabase (sem ferramenta externa no MVP):
  - Rodadas iniciadas vs. finalizadas (`quiz_sessions.finished_at`).
  - Distribuição de pontuação por nível.
  - `question_stats` para identificar perguntas mais erradas e ajustar o conteúdo do treinamento.

---

## 11. Questões em aberto
1. Período de retenção dos e-mails (sugestão: 12 meses) e canal para pedido de exclusão (LGPD).
2. Texto final do aviso de privacidade (link no rodapé).
3. Quem é o responsável (SME) por revisar as perguntas a cada nova versão do Claude Code.
4. Domínio definitivo de publicação.

---

## Apêndice A — Banco inicial de perguntas (seed)

> Conteúdo baseado na documentação oficial do Claude Code. **Validar os links e fatos antes do lançamento**, pois o produto evolui com frequência. Base de links: `https://code.claude.com/docs/en/`.

### A.1 Iniciante (conceitos e negócios)

| # | Afirmação | Resp. | Explicação | Link |
|---|-----------|-------|------------|------|
| 1 | O Claude Code é uma ferramenta de programação agêntica da Anthropic que lê e edita arquivos e executa comandos no seu projeto. | V | Ele atua como um agente: entende a base de código, edita arquivos e roda comandos, sempre sob controle do usuário. | overview |
| 2 | O Claude Code só funciona dentro do navegador; não existe versão para terminal. | F | Ele nasceu como CLI de terminal e também está disponível em app desktop, web e extensões de IDE. | overview |
| 3 | O Claude Code pode ser usado dentro de IDEs como VS Code e JetBrains. | V | Há extensões/integrações oficiais para VS Code e IDEs JetBrains. | ide-integrations |
| 4 | Para usar o Claude Code é obrigatório saber programar em Python. | F | Ele funciona com praticamente qualquer linguagem e as instruções são dadas em linguagem natural. | overview |
| 5 | Por padrão, o Claude Code pede permissão antes de ações como editar arquivos ou executar comandos. | V | O sistema de permissões pede aprovação para ações potencialmente arriscadas, a menos que o usuário as libere. | iam |
| 6 | O Claude Code pode ser usado gratuitamente e sem limites, sem nenhuma conta. | F | É preciso uma conta com plano elegível (ex.: Pro, Max, Team, Enterprise) ou acesso via API/Console. | setup |
| 7 | O Claude Code pode ajudar a entender uma base de código desconhecida respondendo perguntas sobre ela. | V | Perguntar "como funciona este projeto?" é um dos usos mais comuns para onboarding. | common-workflows |
| 8 | O Claude Code só gera código novo; ele não consegue corrigir bugs em código existente. | F | Corrigir bugs a partir de mensagens de erro ou descrições é um dos fluxos principais. | common-workflows |
| 9 | Empresas podem usar o Claude Code por meio de provedores de nuvem como Amazon Bedrock e Google Vertex AI. | V | Há suporte oficial a Bedrock e Vertex AI para implantações corporativas. | third-party-integrations |
| 10 | O Claude Code consegue criar commits e abrir pull requests usando Git. | V | Ele trabalha com Git e com o GitHub CLI para commits, branches e PRs. | common-workflows |
| 11 | Com o Claude Code, a revisão humana do código se torna totalmente desnecessária. | F | O desenvolvedor continua responsável por revisar e aprovar as mudanças. | overview |
| 12 | O arquivo CLAUDE.md serve para dar ao Claude contexto persistente sobre o projeto. | V | Ele é carregado automaticamente e guarda convenções, comandos e instruções do projeto. | memory |
| 13 | O Claude Code funciona apenas em projetos JavaScript. | F | Ele é agnóstico de linguagem e framework. | overview |
| 14 | É possível interromper o Claude Code durante uma tarefa pressionando Esc. | V | Esc interrompe a ação atual sem perder o histórico da conversa. | interactive-mode |
| 15 | O Claude Code só pode ser usado por desenvolvedores profissionais. | F | Também é usado por outros perfis para automatizar tarefas, analisar dados e documentos. | overview |

### A.2 Intermediário (uso no dia a dia)

| # | Afirmação | Resp. | Explicação | Link |
|---|-----------|-------|------------|------|
| 1 | O comando `/init` analisa o projeto e gera um arquivo CLAUDE.md inicial. | V | `/init` cria o CLAUDE.md com uma visão geral do projeto, comandos e convenções. | memory |
| 2 | `/clear` e `/compact` fazem exatamente a mesma coisa. | F | `/clear` limpa o histórico; `/compact` resume a conversa para liberar contexto mantendo o essencial. | slash-commands |
| 3 | No Plan Mode, o Claude analisa o código e propõe um plano sem editar arquivos. | V | O Plan Mode é somente leitura até o usuário aprovar o plano. | common-workflows |
| 4 | Pressionar Shift+Tab alterna entre modos de permissão, como aceitar edições automaticamente e Plan Mode. | V | Shift+Tab percorre os modos de permissão na sessão interativa. | interactive-mode |
| 5 | `claude -p "prompt"` executa em modo não interativo, imprime a resposta e encerra. | V | O modo "print"/headless é usado em scripts e automações. | headless |
| 6 | `claude --continue` sempre inicia uma conversa nova, descartando o histórico. | F | `--continue` retoma a conversa mais recente do diretório; `--resume` permite escolher uma sessão. | cli-reference |
| 7 | Comandos slash personalizados podem ser criados como arquivos Markdown em `.claude/commands/`. | V | Cada arquivo vira um comando reutilizável, que pode ser versionado com o projeto. | slash-commands |
| 8 | O MCP (Model Context Protocol) permite conectar o Claude Code a ferramentas e fontes de dados externas. | V | Servidores MCP expõem ferramentas como bancos de dados, issue trackers e APIs. | mcp |
| 9 | O CLAUDE.md só funciona na raiz do projeto; um `~/.claude/CLAUDE.md` é ignorado. | F | Existem níveis de memória: usuário (`~/.claude/CLAUDE.md`), projeto e subdiretórios. | memory |
| 10 | O Claude Code consegue analisar imagens, como screenshots coladas na conversa. | V | É possível colar ou arrastar imagens (ex.: mockups, erros de UI). | common-workflows |
| 11 | O arquivo `.claude/settings.local.json` foi feito para ser versionado e compartilhado com o time. | F | Ele guarda preferências pessoais e é ignorado pelo Git; o compartilhado é `.claude/settings.json`. | settings |
| 12 | É possível referenciar um arquivo na mensagem digitando `@` seguido do caminho. | V | Menções com `@` incluem o arquivo ou diretório no contexto. | common-workflows |
| 13 | `/compact` apaga todo o histórico sem manter nenhum resumo. | F | `/compact` mantém um resumo da conversa e aceita instruções sobre o que preservar. | slash-commands |
| 14 | O Claude Code não consegue executar os testes do projeto; ele só escreve código. | F | Ele roda testes, lê os resultados e itera até que passem. | common-workflows |
| 15 | Pressionar Esc duas vezes permite voltar a um ponto anterior da conversa. | V | Esc duplo abre a navegação para editar/retomar de uma mensagem anterior (rewind). | interactive-mode |

### A.3 Avançado (configuração e extensibilidade)

| # | Afirmação | Resp. | Explicação | Link |
|---|-----------|-------|------------|------|
| 1 | Hooks são comandos executados automaticamente em eventos do ciclo de vida, como `PreToolUse` e `PostToolUse`. | V | Hooks permitem automatizar formatação, validação, notificações etc. | hooks |
| 2 | Um hook `PreToolUse` que termina com código de saída 2 bloqueia a ferramenta e envia o stderr ao Claude. | V | O exit code 2 é o sinal de bloqueio; a mensagem orienta o Claude a corrigir a ação. | hooks |
| 3 | Hooks são apenas sugestões que o modelo pode decidir ignorar. | F | Hooks são determinísticos: são executados pelo harness, não dependem do modelo. | hooks |
| 4 | Subagentes personalizados podem ser definidos em arquivos Markdown com frontmatter em `.claude/agents/`. | V | O frontmatter define nome, descrição, ferramentas e modelo do subagente. | sub-agents |
| 5 | Um subagente compartilha exatamente a mesma janela de contexto da conversa principal. | F | Cada subagente tem seu próprio contexto, o que preserva o contexto principal. | sub-agents |
| 6 | Configurações gerenciadas (managed/enterprise) têm precedência sobre as configurações de usuário e de projeto. | V | A política gerenciada fica no topo da hierarquia e não pode ser sobrescrita. | settings |
| 7 | Servidores MCP com escopo de projeto ficam só na memória e não podem ser compartilhados com o time. | F | O escopo de projeto usa o arquivo `.mcp.json` na raiz, que pode ser versionado. | mcp |
| 8 | A flag `--dangerously-skip-permissions` é recomendada para uso diário em máquinas com dados sensíveis. | F | Ela desativa as confirmações e só deve ser usada em ambientes isolados (ex.: containers sem acesso à internet). | iam |
| 9 | Regras de permissão no `settings.json` podem usar listas `allow` e `deny`, como `Bash(npm run test:*)`. | V | As regras usam o padrão `Ferramenta(especificador)`. | iam |
| 10 | O Claude Agent SDK permite construir agentes customizados com a mesma base do Claude Code. | V | O SDK expõe o loop agêntico, ferramentas e gerenciamento de contexto. | sdk |
| 11 | O Claude Code pode ser integrado ao GitHub Actions para responder a menções `@claude` em issues e PRs. | V | A integração oficial executa o Claude Code no CI a partir de menções. | github-actions |
| 12 | Todas as Skills são carregadas integralmente no contexto em toda sessão, sejam relevantes ou não. | F | Skills usam divulgação progressiva: só nome e descrição ficam no contexto até serem necessárias. | skills |
| 13 | No CLAUDE.md é possível importar outros arquivos com a sintaxe `@caminho/arquivo`. | V | Imports permitem modularizar instruções de memória. | memory |
| 14 | Se um comando estiver em `allow` e em `deny`, ele é permitido, pois `allow` tem prioridade. | F | Regras `deny` prevalecem sobre `allow`. | iam |
| 15 | Git worktrees permitem rodar várias sessões do Claude Code em paralelo, em branches isoladas. | V | Cada worktree tem seu próprio diretório de trabalho, evitando conflitos entre sessões. | common-workflows |

> No `seed.sql`, a coluna **Link** deve ser expandida para a URL completa (ex.: `https://code.claude.com/docs/en/hooks`).
