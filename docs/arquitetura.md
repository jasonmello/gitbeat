# Arquitetura

## Fluxo
```
~/.claude/projects/**/*.jsonl ─► UsageStore (incremental) ─┐
~/.local/share/opencode/*.db ──► OpenCodeReader (SQLite) ──┤
~/.codex/{sessions,archived_sessions} ─► FileSource+CodexParser ─┼─► dedupe ─► HistoryArchive (Mac + iCloud) ─► AppModel ─► telas
~/.gemini/tmp/*/chats ─────────► FileSource+GeminiParser ──┘
gh api graphql ────────────────► GitHubClient ─► GitHubSnapshot ─────────────────────────────► AppModel
```

## Claude Code (`Sources/GitBeatCore/UsageStore.swift`, `Sources/GitBeatCore/UsageRecord.swift`)
- Linhas `type: "assistant"` com `message.usage`. `JSONLReader` só faz parse de linhas com `"usage"` e `"assistant"` (filtro com `memmem`). 3,2 GB levam ~20–30 s na primeira vez; depois, menos de 1 s.
- Cache por arquivo (tamanho, data, offset) em `~/Library/Application Support/GitBeat/claude-usage.json`.
- O mesmo `message.id` aparece em várias linhas com o mesmo `usage`: conta uma vez (`UsageStore.dedupe`).
- Projeto = último componente do `cwd`; worktrees contam como o projeto-mãe; pastas temporárias do app Claude viram "No folder".

## Outras ferramentas (`Sources/GitBeatCore/OtherTools.swift`)
Formatos lidos do código-fonte de cada uma em 2026-11-19 e conferidos com os arquivos reais desta máquina quando havia.
- **Codex CLI** (conferido com dados reais, bate com soma independente): `.jsonl` por sessão. `session_meta`/`turn_context` dão `cwd` e `model`; `event_msg` → `token_count` traz `info.total_token_usage` acumulado. Usamos a diferença do acumulado (eventos repetidos não somam). `input_tokens` inclui o cache: entrada = input − cached.
- **OpenCode**: SQLite, tabelas `session_message` (tipo `assistant`, coluna `data` JSON com `tokens` e `cost`) e `session_v2` (`directory`). Nesta máquina não há mensagens com tokens. Também lê o formato antigo (um JSON por mensagem em `~/.local/share/opencode/storage/message`). Custo gravado pelo OpenCode vence a tabela de preços.
- **Gemini CLI**: `.jsonl` (ou `.json` antigo) em `~/.gemini/tmp/<projeto>/chats/`. A mesma mensagem é regravada: vale a última linha de cada `id`. Entrada = input − cached + tool; saída = output + thoughts. Não testado com dados reais.
- Cursor e Antigravity guardam uso na conta online: não suportados.

## Histórico (`Sources/GitBeatCore/HistoryArchive.swift`)
- Guarda só números. Um arquivo por mês por Mac: `<id do Mac>/aaaa-mm.json`, em `~/Library/Application Support/GitBeat/History` e em `iCloud Drive/GitBeat/History` (se o iCloud Drive estiver ligado).
- Cada Mac só escreve na própria pasta (sem conflito de sincronização). Na leitura, junta todas as pastas; os registros deste Mac voltam para o arquivo, os de outros Macs só entram na conta.
- Só regrava meses que ganharam registros. Arquivos ainda não baixados do iCloud (`.icloud`) disparam o download e entram na próxima leitura.
- O Claude Code apaga transcrições antigas (padrão de 30 dias); o histórico continua com elas.

## Estatísticas (`Sources/GitBeatCore/Stats.swift`, `Sources/GitBeatCore/Pricing.swift`)
- Dias são chaves `aaaa-mm-dd` no fuso local (`DayKeys`). Tempo ativo: intervalos de até 15 min numa linha do tempo única. Sequência: dia com resposta ou commit.
- Custo: `costUSD` gravado pela ferramenta ou tabela de preços da Anthropic; modo rápido 2×. Modelos fora da tabela contam zero.

## GitHub (`Sources/GitBeatCore/GitHub.swift`)
- Pelo `gh` (procurado em `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`). Commits pelo histórico do branch principal de cada repositório (inclui privados), até 100 por repositório no ano. PRs pela busca, até 1.000. Cache `github-v2.json`, relido após 10 min, ao acordar o Mac ou no Refresh.

## Abrir no login e notificações (`Sources/GitBeat/SystemIntegration.swift`, `Sources/GitBeatCore/NotificationPlanner.swift`)
- Só funcionam como `.app` (com bundle identifier); por `swift run` ficam desligados.
- Abrir no login: `SMAppService.mainApp`, ligado sozinho na primeira abertura como app; a chave nos Ajustes reflete o estado real do sistema. Registra o caminho do app em uso, por isso o app deve rodar de /Applications (`scripts/build-app.sh --install`).
- Notificações: `NotificationPlanner` decide (função pura, com checagens); `Notifier` executa depois de cada atualização. Anéis fechados: uma vez por dia. Sequência em risco: lembrete agendado no horário escolhido (padrão 21h) se hoje ainda não teve atividade; é cancelado e reagendado a cada atualização, então some assim que aparece atividade.
- `GitBeat --integration-status` pede a permissão e imprime o resultado, o estado do item de login e o da permissão de notificações.
- Sem permissão de notificação, o lembrete aparece no ícone da barra de menu: vira uma chama depois do horário do lembrete quando hoje está sem atividade e há sequência (`AppModel.streakAtRisk`).

## App (`Sources/GitBeat/`)
- `AppModel` relê as ferramentas ao abrir, a cada 2 min (`autoRefreshInterval`, timer no modo `.common`), ao acordar o Mac e ao voltar para o app ou abrir o painel da barra de menu, se os dados tiverem mais de 1 min. O GitHub é consultado quando os dados dele têm mais de 10 min, ao acordar e no botão Atualizar. Tudo em `Task.detached`. Migra a pasta antiga `SaudeDev` na primeira abertura.
- `Preferences`: idioma (padrão inglês), visual (padrão Liquid Glass) e tema, em UserDefaults; `T()` lê o idioma e as telas redesenham ao trocar.
- Cenas: `Window` principal, `MenuBarExtra`, `Settings` (General + Goals). Painel Sobre com o crédito.
- `Sources/GitBeat/Snapshot.swift`: `--snapshot` desenha as telas com `ImageRenderer` (desenha o vidro; controles nativos saem como faixas amarelas) e `--render-icon` gera o ícone.
