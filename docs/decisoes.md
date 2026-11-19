# Decisões

- **2026-11-19 · App nativo (SwiftUI + Swift Charts), não página web.** Barra de menu e cara de app Saúde; o Jason escolheu.
- **2026-11-19 · Swift Package sem Xcode.** A máquina só tem as Command Line Tools. O `.app` é montado por `scripts/build-app.sh` com assinatura ad hoc.
- **2026-11-19 · `@ViewState` no lugar de `@State`.** No SDK do macOS 27, `@State` virou macro e o plugin dela só vem com o Xcode. O wrapper guarda um `State` por dentro e funciona igual.
- **2026-11-19 · Checagens como executável (`GitBeatChecks`), não Swift Testing/XCTest.** As Command Line Tools não trazem o plugin de macros do Swift Testing nem o XCTest.
- **2026-11-19 · Commits pelo histórico de cada repositório, não pelo calendário de contribuições.** O calendário escondia os repositórios privados (51 commits no ano contra 126 reais), porque a opção de contribuições privadas do perfil está desligada.
- **2026-11-19 · Custo mostrado como "equivalente a preço de API".** Na assinatura não se paga por token, mas o número dá a escala do uso.
- **2026-11-19 · Metas padrão: 400 mi tokens, 4 h, 3 commits.** Tirado da média real da semana (~400 mi tokens/dia, quase tudo leitura de cache).
- **2026-11-19 · Nome GitBeat, com o logo de `brand/`.** O app deixou de se chamar Saúde Dev; a pasta de dados antiga é migrada sozinha.
- **2026-11-19 · Inglês é o idioma original; português é opção nos Ajustes.** Textos lado a lado em `T(en, pt)` em vez de arquivos `.strings`: sem recurso empacotado (o build não usa Xcode) e cada tradução fica ao lado do original.
- **2026-11-19 · Liquid Glass é o visual oficial; Clássico continua como opção e fallback antes do macOS 26.**
- **2026-11-19 · Histórico permanente no Mac com cópia no iCloud Drive.** Só números, nunca texto. Um arquivo por mês por Mac evita conflito de sincronização. Escolhido no lugar de repositório no GitHub (geraria commits diários) e de serviço na nuvem (exigiria conta e servidor).
- **2026-11-19 · Também lê OpenCode, Codex CLI e Gemini CLI.** Cursor e Antigravity ficam de fora: guardam uso só na conta online.
