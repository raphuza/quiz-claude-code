-- Quiz Claude Code — banco inicial de perguntas (PRD, Apêndice A) e palavras bloqueadas.
-- Executar após migrations/001_schema.sql.
-- Validar fatos e links antes do lançamento: o Claude Code evolui com frequência.
-- Para desativar uma pergunta: update questions set active = false where id = ...;

insert into questions (level, statement, answer, explanation, doc_url) values
-- A.1 Iniciante (conceitos e negócios)
('iniciante', 'O Claude Code é uma ferramenta de programação agêntica da Anthropic que lê e edita arquivos e executa comandos no seu projeto.', true, 'Ele atua como um agente: entende a base de código, edita arquivos e roda comandos, sempre sob controle do usuário.', 'https://code.claude.com/docs/en/overview'),
('iniciante', 'O Claude Code só funciona dentro do navegador; não existe versão para terminal.', false, 'Ele nasceu como CLI de terminal e também está disponível em app desktop, web e extensões de IDE.', 'https://code.claude.com/docs/en/overview'),
('iniciante', 'O Claude Code pode ser usado dentro de IDEs como VS Code e JetBrains.', true, 'Há extensões/integrações oficiais para VS Code e IDEs JetBrains.', 'https://code.claude.com/docs/en/ide-integrations'),
('iniciante', 'Para usar o Claude Code é obrigatório saber programar em Python.', false, 'Ele funciona com praticamente qualquer linguagem e as instruções são dadas em linguagem natural.', 'https://code.claude.com/docs/en/overview'),
('iniciante', 'Por padrão, o Claude Code pede permissão antes de ações como editar arquivos ou executar comandos.', true, 'O sistema de permissões pede aprovação para ações potencialmente arriscadas, a menos que o usuário as libere.', 'https://code.claude.com/docs/en/iam'),
('iniciante', 'O Claude Code pode ser usado gratuitamente e sem limites, sem nenhuma conta.', false, 'É preciso uma conta com plano elegível (ex.: Pro, Max, Team, Enterprise) ou acesso via API/Console.', 'https://code.claude.com/docs/en/setup'),
('iniciante', 'O Claude Code pode ajudar a entender uma base de código desconhecida respondendo perguntas sobre ela.', true, 'Perguntar "como funciona este projeto?" é um dos usos mais comuns para onboarding.', 'https://code.claude.com/docs/en/common-workflows'),
('iniciante', 'O Claude Code só gera código novo; ele não consegue corrigir bugs em código existente.', false, 'Corrigir bugs a partir de mensagens de erro ou descrições é um dos fluxos principais.', 'https://code.claude.com/docs/en/common-workflows'),
('iniciante', 'Empresas podem usar o Claude Code por meio de provedores de nuvem como Amazon Bedrock e Google Vertex AI.', true, 'Há suporte oficial a Bedrock e Vertex AI para implantações corporativas.', 'https://code.claude.com/docs/en/third-party-integrations'),
('iniciante', 'O Claude Code consegue criar commits e abrir pull requests usando Git.', true, 'Ele trabalha com Git e com o GitHub CLI para commits, branches e PRs.', 'https://code.claude.com/docs/en/common-workflows'),
('iniciante', 'Com o Claude Code, a revisão humana do código se torna totalmente desnecessária.', false, 'O desenvolvedor continua responsável por revisar e aprovar as mudanças.', 'https://code.claude.com/docs/en/overview'),
('iniciante', 'O arquivo CLAUDE.md serve para dar ao Claude contexto persistente sobre o projeto.', true, 'Ele é carregado automaticamente e guarda convenções, comandos e instruções do projeto.', 'https://code.claude.com/docs/en/memory'),
('iniciante', 'O Claude Code funciona apenas em projetos JavaScript.', false, 'Ele é agnóstico de linguagem e framework.', 'https://code.claude.com/docs/en/overview'),
('iniciante', 'É possível interromper o Claude Code durante uma tarefa pressionando Esc.', true, 'Esc interrompe a ação atual sem perder o histórico da conversa.', 'https://code.claude.com/docs/en/interactive-mode'),
('iniciante', 'O Claude Code só pode ser usado por desenvolvedores profissionais.', false, 'Também é usado por outros perfis para automatizar tarefas, analisar dados e documentos.', 'https://code.claude.com/docs/en/overview'),

-- A.2 Intermediário (uso no dia a dia)
('intermediario', 'O comando `/init` analisa o projeto e gera um arquivo CLAUDE.md inicial.', true, '`/init` cria o CLAUDE.md com uma visão geral do projeto, comandos e convenções.', 'https://code.claude.com/docs/en/memory'),
('intermediario', '`/clear` e `/compact` fazem exatamente a mesma coisa.', false, '`/clear` limpa o histórico; `/compact` resume a conversa para liberar contexto mantendo o essencial.', 'https://code.claude.com/docs/en/slash-commands'),
('intermediario', 'No Plan Mode, o Claude analisa o código e propõe um plano sem editar arquivos.', true, 'O Plan Mode é somente leitura até o usuário aprovar o plano.', 'https://code.claude.com/docs/en/common-workflows'),
('intermediario', 'Pressionar Shift+Tab alterna entre modos de permissão, como aceitar edições automaticamente e Plan Mode.', true, 'Shift+Tab percorre os modos de permissão na sessão interativa.', 'https://code.claude.com/docs/en/interactive-mode'),
('intermediario', '`claude -p "prompt"` executa em modo não interativo, imprime a resposta e encerra.', true, 'O modo "print"/headless é usado em scripts e automações.', 'https://code.claude.com/docs/en/headless'),
('intermediario', '`claude --continue` sempre inicia uma conversa nova, descartando o histórico.', false, '`--continue` retoma a conversa mais recente do diretório; `--resume` permite escolher uma sessão.', 'https://code.claude.com/docs/en/cli-reference'),
('intermediario', 'Comandos slash personalizados podem ser criados como arquivos Markdown em `.claude/commands/`.', true, 'Cada arquivo vira um comando reutilizável, que pode ser versionado com o projeto.', 'https://code.claude.com/docs/en/slash-commands'),
('intermediario', 'O MCP (Model Context Protocol) permite conectar o Claude Code a ferramentas e fontes de dados externas.', true, 'Servidores MCP expõem ferramentas como bancos de dados, issue trackers e APIs.', 'https://code.claude.com/docs/en/mcp'),
('intermediario', 'O CLAUDE.md só funciona na raiz do projeto; um `~/.claude/CLAUDE.md` é ignorado.', false, 'Existem níveis de memória: usuário (`~/.claude/CLAUDE.md`), projeto e subdiretórios.', 'https://code.claude.com/docs/en/memory'),
('intermediario', 'O Claude Code consegue analisar imagens, como screenshots coladas na conversa.', true, 'É possível colar ou arrastar imagens (ex.: mockups, erros de UI).', 'https://code.claude.com/docs/en/common-workflows'),
('intermediario', 'O arquivo `.claude/settings.local.json` foi feito para ser versionado e compartilhado com o time.', false, 'Ele guarda preferências pessoais e é ignorado pelo Git; o compartilhado é `.claude/settings.json`.', 'https://code.claude.com/docs/en/settings'),
('intermediario', 'É possível referenciar um arquivo na mensagem digitando `@` seguido do caminho.', true, 'Menções com `@` incluem o arquivo ou diretório no contexto.', 'https://code.claude.com/docs/en/common-workflows'),
('intermediario', '`/compact` apaga todo o histórico sem manter nenhum resumo.', false, '`/compact` mantém um resumo da conversa e aceita instruções sobre o que preservar.', 'https://code.claude.com/docs/en/slash-commands'),
('intermediario', 'O Claude Code não consegue executar os testes do projeto; ele só escreve código.', false, 'Ele roda testes, lê os resultados e itera até que passem.', 'https://code.claude.com/docs/en/common-workflows'),
('intermediario', 'Pressionar Esc duas vezes permite voltar a um ponto anterior da conversa.', true, 'Esc duplo abre a navegação para editar/retomar de uma mensagem anterior (rewind).', 'https://code.claude.com/docs/en/interactive-mode'),

-- A.3 Avançado (configuração e extensibilidade)
('avancado', 'Hooks são comandos executados automaticamente em eventos do ciclo de vida, como `PreToolUse` e `PostToolUse`.', true, 'Hooks permitem automatizar formatação, validação, notificações etc.', 'https://code.claude.com/docs/en/hooks'),
('avancado', 'Um hook `PreToolUse` que termina com código de saída 2 bloqueia a ferramenta e envia o stderr ao Claude.', true, 'O exit code 2 é o sinal de bloqueio; a mensagem orienta o Claude a corrigir a ação.', 'https://code.claude.com/docs/en/hooks'),
('avancado', 'Hooks são apenas sugestões que o modelo pode decidir ignorar.', false, 'Hooks são determinísticos: são executados pelo harness, não dependem do modelo.', 'https://code.claude.com/docs/en/hooks'),
('avancado', 'Subagentes personalizados podem ser definidos em arquivos Markdown com frontmatter em `.claude/agents/`.', true, 'O frontmatter define nome, descrição, ferramentas e modelo do subagente.', 'https://code.claude.com/docs/en/sub-agents'),
('avancado', 'Um subagente compartilha exatamente a mesma janela de contexto da conversa principal.', false, 'Cada subagente tem seu próprio contexto, o que preserva o contexto principal.', 'https://code.claude.com/docs/en/sub-agents'),
('avancado', 'Configurações gerenciadas (managed/enterprise) têm precedência sobre as configurações de usuário e de projeto.', true, 'A política gerenciada fica no topo da hierarquia e não pode ser sobrescrita.', 'https://code.claude.com/docs/en/settings'),
('avancado', 'Servidores MCP com escopo de projeto ficam só na memória e não podem ser compartilhados com o time.', false, 'O escopo de projeto usa o arquivo `.mcp.json` na raiz, que pode ser versionado.', 'https://code.claude.com/docs/en/mcp'),
('avancado', 'A flag `--dangerously-skip-permissions` é recomendada para uso diário em máquinas com dados sensíveis.', false, 'Ela desativa as confirmações e só deve ser usada em ambientes isolados (ex.: containers sem acesso à internet).', 'https://code.claude.com/docs/en/iam'),
('avancado', 'Regras de permissão no `settings.json` podem usar listas `allow` e `deny`, como `Bash(npm run test:*)`.', true, 'As regras usam o padrão `Ferramenta(especificador)`.', 'https://code.claude.com/docs/en/iam'),
('avancado', 'O Claude Agent SDK permite construir agentes customizados com a mesma base do Claude Code.', true, 'O SDK expõe o loop agêntico, ferramentas e gerenciamento de contexto.', 'https://code.claude.com/docs/en/sdk'),
('avancado', 'O Claude Code pode ser integrado ao GitHub Actions para responder a menções `@claude` em issues e PRs.', true, 'A integração oficial executa o Claude Code no CI a partir de menções.', 'https://code.claude.com/docs/en/github-actions'),
('avancado', 'Todas as Skills são carregadas integralmente no contexto em toda sessão, sejam relevantes ou não.', false, 'Skills usam divulgação progressiva: só nome e descrição ficam no contexto até serem necessárias.', 'https://code.claude.com/docs/en/skills'),
('avancado', 'No CLAUDE.md é possível importar outros arquivos com a sintaxe `@caminho/arquivo`.', true, 'Imports permitem modularizar instruções de memória.', 'https://code.claude.com/docs/en/memory'),
('avancado', 'Se um comando estiver em `allow` e em `deny`, ele é permitido, pois `allow` tem prioridade.', false, 'Regras `deny` prevalecem sobre `allow`.', 'https://code.claude.com/docs/en/iam'),
('avancado', 'Git worktrees permitem rodar várias sessões do Claude Code em paralelo, em branches isoladas.', true, 'Cada worktree tem seu próprio diretório de trabalho, evitando conflitos entre sessões.', 'https://code.claude.com/docs/en/common-workflows');

-- Palavras bloqueadas (comparadas como palavra inteira, sem diferenciar maiúsculas).
insert into blocked_words (word) values
  ('porra'), ('caralho'), ('merda'), ('puta'), ('puto'), ('buceta'), ('foda'), ('fodase'),
  ('viado'), ('cuzao'), ('cuzão'), ('arrombado'), ('vagabunda'), ('fdp'), ('pqp'),
  ('nazista'), ('hitler')
on conflict do nothing;
