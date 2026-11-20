# Decisões

- **2026-11-19 · App nativo (SwiftUI + Swift Charts), não página web.** Barra de menu e painel com anéis de meta; o Jason escolheu.
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
- **2026-11-19 · Abrir no login ligado na primeira abertura; notificações de anéis e de sequência ligadas por padrão.** O app vive na barra de menu e o lembrete só funciona se ele estiver rodando; tudo pode ser desligado nos Ajustes.
- **2026-11-19 · Notificações ficam no código, com aviso nos Ajustes e chama na barra de menu como alternativa.** Nesta máquina o macOS responde "Notifications are not allowed for this application" ao app assinado ad hoc, mesmo registrado no LaunchServices e aberto pelo `open`. A causa provável é a falta de assinatura Developer ID (não confirmada); deve sumir quando o app for assinado para distribuição.
- **2026-11-19 · Licença: não será MIT.** Será outro formato, definido quando o projeto for publicado. Até lá, nenhum arquivo de licença no repositório e nenhum texto (site, README) dizendo que é código aberto.
- **2026-11-19 · Site de apresentação em `site/`, HTML estático sem dependências.** Feito a partir do template visual enviado pelo Jason; fonte do sistema (sem Google Fonts, nenhuma requisição a terceiros). Publicação (GitHub Pages) fica para quando o repositório for público.
- **2026-11-19 · Sem "Apple Health" nem comparações com produtos da Apple.** São marcas registradas e podem sugerir vínculo com a Apple. Slogan novo: "Your coding rhythm, at a glance". Nomes da plataforma (macOS, iCloud Drive, Xcode) seguem, por descreverem onde o app roda.
