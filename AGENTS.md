# GitBeat

App de Mac para quem programa com IA, com anéis de meta e sequências: tokens por dia (Claude Code, OpenCode, Codex CLI, Gemini CLI), tempo ativo, commits e PRs do GitHub, anéis de meta e sequências. Nativo (SwiftUI + Swift Charts), janela + barra de menu, Liquid Glass. Inglês é o idioma original; português é opção. Tudo local, com cópia do histórico no iCloud Drive.

## Onde está cada coisa
- `Sources/GitBeatCore/`: lógica sem interface. `UsageStore.swift` (Claude Code), `OtherTools.swift` (OpenCode, Codex, Gemini), `HistoryArchive.swift` (histórico permanente), `Stats.swift`, `Pricing.swift`, `GitHub.swift`.
- `Sources/GitBeat/`: o app. `AppModel.swift` junta os dados; `SystemIntegration.swift` cuida de abrir no login e das notificações; `Preferences.swift` tem idioma, visual e tema (e a função `T`); `Theme.swift` tem os tokens visuais; `Brand.swift` a marca; `Sources/GitBeat/Views/` as telas.
- `site/`: página de apresentação (um `site/index.html` só, sem dependências; imagens em `site/assets/`). `brand/`: SVGs originais do logo. `Tests/GitBeatChecks/main.swift`: checagens. `scripts/`: build e conferência de docs.

## Comandos
- Checagens: `swift run GitBeatChecks` · com os dados reais: `swift run -c release GitBeatChecks --real`
- Rodar: `swift run GitBeat` · Montar o app: `scripts/build-app.sh` (`--install` copia para /Applications)
- Capturas de todas as telas (en/pt, glass/clássico, claro/escuro): `.build/release/GitBeat --snapshot <pasta>`
- Docs: `scripts/check-docs.sh` · Site local: configuração `site` em `.claude/launch.json` (porta 8787)

## Regras que não se quebram
- Compila só com as Command Line Tools: nada de `@State` (use `@ViewState`) nem macros do Swift Testing. Motivo em `docs/decisoes.md`.
- Todo texto de tela passa por `T("inglês", "português")`. Inglês é o original.
- O histórico guarda só números, nunca texto de conversa. Cada Mac escreve só na própria pasta.
- Nenhum dado sai do Mac além das chamadas do `gh` e da cópia no iCloud Drive do próprio usuário.
- Preços em `Sources/GitBeatCore/Pricing.swift`, conferidos na fonte oficial com data. Nunca de memória.
- Identificadores de ferramenta (`Tool`) ficam gravados no histórico: não mudar.
- Licença ainda não definida e **não será MIT**: não adicionar arquivo de licença nem chamar o projeto de código aberto. Ver `docs/decisoes.md`.

## Não verificado
- Gemini CLI: nenhum chat nesta máquina; leitor testado só com exemplo montado. OpenCode: instalado, mas sem uso (0 tokens); leitor testado com exemplo.
- Build no Xcode completo não rodou (o CI no macOS compila e passa nas checagens). Sincronização entre dois Macs pelo iCloud não foi testada com um segundo Mac.
- Abrir no login: funcionando (conferido com `--integration-status`). Notificações: o macOS recusa ("not allowed") para o app assinado só localmente; provável causa é a falta de Developer ID, não confirmada. Ver `docs/decisoes.md`.

## Antes de X, leia Y
| Antes de… | Leia |
|---|---|
| mexer em interface ou texto | `DESIGN.md` |
| mudar leitura de dados, histórico ou GitHub | `docs/arquitetura.md` |
| mudar uma decisão já tomada | `docs/decisoes.md` |
| commit, PR ou merge | skill `fluxo-github` |
