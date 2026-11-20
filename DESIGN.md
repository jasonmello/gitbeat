# DESIGN.md: GitBeat

Valores tirados de `Sources/GitBeat/Theme.swift`, `Sources/GitBeat/Brand.swift` e `Sources/GitBeat/Views/Components.swift`. Mudou lá, mude aqui no mesmo PR.

## Princípios
- **Painel de atividade.** Cartões com título colorido e ícone, número grande, gráfico embaixo. Anéis para metas.
- **Marca própria.** Nada de comparar com produtos de outras empresas ("Apple Health", "app Saúde", relógio) em texto, slogan ou código: são marcas registradas. Citar a plataforma para dizer onde o app roda (macOS, iCloud Drive, Xcode) pode.
- **Número primeiro, explicação em uma linha.** Cada cartão responde uma pergunta ("how much today?").
- **Honesto.** Custo é "equivalent at API prices"; o que é estimativa diz que é. A página About the data explica cada diferença que o usuário pode notar.
- **Nativo, do jeito do sistema.** Liquid Glass na camada que flutua sobre o conteúdo (barra lateral, barra de ferramentas, dica do gráfico, painel da barra de menu); o conteúdo fica em cartões sólidos sobre fundo neutro, porque texto sobre vidro perde contraste conforme o que está atrás. Clássico tira o vidro também da dica do gráfico e é o que aparece antes do macOS 26.
- **Cor nos dados, não no fundo.** A cor do assunto vai no anel, na barra, no título do cartão e no pontinho da legenda. Rótulos de apoio, setas e "Today" ficam em cinza.

## Marca
- Nome: **GitBeat**. Verde da marca `Brand.green` = #00C995. Nome do logo em #1C2025 (claro) e #ECEDEE (escuro), via `BrandLogo`.
- Logo no topo da barra lateral e no menu da barra; ícone do app gerado de `AppIconArt` (fundo branco arredondado, marca verde).
- Crédito: "Proudly developed by Jason Mello" (`CreditLine`), no rodapé da barra lateral, nos Ajustes, em About the data e no painel Sobre. **O nome é sempre um link para https://github.com/jasonmello** (`Brand.authorURL`), também no site e no README. No app: semibold na cor do texto, sublinha e mostra a mãozinha no hover.

## Cores (uma por assunto, usadas em tudo daquele assunto)
| Assunto | Cor | Onde |
|---|---|---|
| Tokens | `Theme.tokens` = rosa | anel externo, gráficos de tokens |
| Tempo | `Theme.time` = teal | anel do meio, tela Time |
| GitHub | `Theme.github` = verde da marca | anel interno, commits, quadriculado |
| Custo | `Theme.cost` = roxo | custo equivalente, "by model" |
| Sequência | `Theme.streak` = laranja | chama, recorde, metas |

Neutros quentes, nunca preto/branco puros: página `Theme.page` (#f3f3f1 / #0b0b0c), cartão `Theme.raised` (#fefefd / #1c1c1e), trilhas `Theme.well`, anel `Theme.hairline`. Barras: hoje cheio com gradiente, outros dias com opacidade 0,45 e canto 4 (`MiniBars`). Trilha do anel: a cor do assunto com opacidade 0,2.

## Visual
- **Fundo** (`AppBackground`): só o neutro da página, sem manchas coloridas.
- **Cartão** (`cardSurface`): sólido, anel de 1px, luz de 1px no topo, sombra em duas camadas de alfa baixo (mais forte no escuro e no hover). Sombra só no fundo, nunca no conteúdo.
- **Flutuante** (`floatingSurface`): `glassEffect` no Liquid Glass; cartão sólido elevado no Clássico.
- **Painel da barra de menu** (`MenuBarView`): número na cor do texto, cor do assunto só no anel e no pontinho do rótulo; sequência e custo em cápsulas `Theme.well`; botão "Open GitBeat" largo, atualizar e sair como ícones sem borda.
- Tema: Automático, Claro ou Escuro (`Preferences.mode`).

## Tipografia
- Fonte do sistema em tudo (SF Pro; SF Pro Rounded nos números). Nada de mono.
- Título de página: 28pt bold, tracking −0,6, com sobretítulo `eyebrow` (`PageHeader`).
- `eyebrow`: 11pt semibold, caixa alta, tracking +0,4, cinza. Usado em rótulos como "DAILY AVERAGE" e "TOKENS".
- Número grande: 32pt rounded bold, tracking −0,6, dígitos tabulares (`BigValue`); unidade em title3 rounded semibold cinza. Legenda dos anéis: 24pt rounded bold na cor do assunto, meta "/400M" na mesma cor a 75%.
- Título de cartão: headline na cor do assunto, ícone hierárquico. Rótulo à direita ("Today", "Week"): subheadline cinza; seta em cinza terciário. Apoio: callout cinza; rodapé: caption cinza.
- Todo número com `monospacedDigit`.

## Espaço e forma
- Raio por papel (`Theme.Radius`): controle 8, cartão 18, painel 22. Padding de cartão 16, espaço entre cartões 16, página com padding 24 e largura máxima 1040.

## Movimento (`Motion`)
- Curva única `timingCurve(0.22, 1, 0.36, 1)`: instant 0,12 s, fast 0,16 s, regular 0,24 s, considered 0,48 s. Saída `(0.7, 0, 0.84, 0)` 0,12 s.
- Anéis fecham do zero ao valor ao aparecer (0,48 s). Acima de 100% o anel dá outra volta por cima, e só a ponta faz sombra (até 300%). Volta fechada certinha (200%, 300%) não tem ponta.
- Resumo: o cartão de hoje mostra os anéis dos últimos 7 dias (`WeekRings`) quando cabe; o de sequência mostra a semana em bolinhas (`StreakWeek`: cheia com check, hoje tracejado se ainda vazio). Cartão clicável: sobe no hover, escala 0,98 ao pressionar, anel de foco com respiro.
- Tudo passa por `.motion(_:value:)`, que desliga com "Reduzir movimento".

## Estados
Carregando: `LoadingPage` com skeleton e brilho. Vazio: `EmptyPage`/`EmptyNote`. Erro do GitHub: cartão laranja com o texto selecionável e "mostrando os últimos dados salvos".

## Site (`site/index.html`)
- Mesma marca e cores dos assuntos; tokens no `:root` do arquivo. Escuro é o padrão; claro e escuro seguem o sistema, com botão para trocar. Inglês original, botão PT.
- No tema claro, texto em verde usa `--accent-text` (#00825f), porque o verde da marca não tem contraste em fundo claro; botões e gráficos mantêm o #00C995.
- Imagens só de telas sem dados privados (Resumo, Tempo, Metas). Nada de nomes de repositório, títulos de PR ou projetos.
- Movimento: linha de batimento desenhada no topo, anéis fechando e barras subindo ao entrar na tela; tudo desliga com "reduzir movimento".

## Voz e conteúdo
- Inglês original, português como opção, sempre lado a lado em `T("…", "…")`.
- Frases curtas, fatos concretos, sem jargão quando dá. Erro diz o que fazer.
- Notificações: título curto e uma frase com o número que importa ("Your 5-day streak ends today"). No máximo uma de anéis por dia e um lembrete de sequência.
- Números: en `598M`, `1.2B`, `35K`, `4h 06m`, `$277.45`; pt `598 mi`, `1,2 bi`, `35 mil`, `4h 06min`, `US$ 277,45` (`Fmt`).
