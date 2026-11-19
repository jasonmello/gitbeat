# DESIGN.md: GitBeat

Valores tirados de `Sources/GitBeat/Theme.swift`, `Sources/GitBeat/Brand.swift` e `Sources/GitBeat/Views/Components.swift`. Mudou lá, mude aqui no mesmo PR.

## Princípios
- **Parece o app Saúde.** Cartões com título colorido e ícone, número grande, gráfico embaixo. Anéis para metas.
- **Número primeiro, explicação em uma linha.** Cada cartão responde uma pergunta ("how much today?").
- **Honesto.** Custo é "equivalent at API prices"; o que é estimativa diz que é. A página About the data explica cada diferença que o usuário pode notar.
- **Nativo.** Liquid Glass do sistema como visual oficial; Clássico como alternativa e como fallback antes do macOS 26.

## Marca
- Nome: **GitBeat**. Verde da marca `Brand.green` = #00C995. Nome do logo em #1C2025 (claro) e #ECEDEE (escuro), via `BrandLogo`.
- Logo no topo da barra lateral e no menu da barra; ícone do app gerado de `AppIconArt` (fundo branco arredondado, marca verde).
- Crédito: "Proudly developed by Jason Mello" (`CreditLine`), no rodapé da barra lateral, nos Ajustes, em About the data e no painel Sobre.

## Cores (uma por assunto, usadas em tudo daquele assunto)
| Assunto | Cor | Onde |
|---|---|---|
| Tokens | `Theme.tokens` = rosa | anel externo, gráficos de tokens |
| Tempo | `Theme.time` = teal | anel do meio, tela Time |
| GitHub | `Theme.github` = verde da marca | anel interno, commits, quadriculado |
| Custo | `Theme.cost` = roxo | custo equivalente, "by model" |
| Sequência | `Theme.streak` = laranja | chama, recorde, metas |

Neutros quentes, nunca preto/branco puros: página `Theme.page` (#f5f5f3 / #0e0e0f), cartão clássico `Theme.raised` (#fdfdfc / #19191b), trilhas `Theme.well`, anel `Theme.hairline`. Barras: hoje cheio com gradiente, outros dias com opacidade 0,32 (`MiniBars`).

## Visual
- **Liquid Glass (padrão):** cartões com `glassEffect` (interativo nos clicáveis). Fundo `AppBackground` com três manchas de luz desfocadas nas cores dos assuntos (opacidade 0,22 claro / 0,30 escuro), para o vidro ter o que refratar.
- **Clássico:** cartão sólido, anel de 1px, luz de 1px no topo, sombra em duas camadas de alfa baixo (mais forte no escuro). Sombra só no fundo, nunca no conteúdo.
- Tema: Automático, Claro ou Escuro (`Preferences.mode`).

## Tipografia
- Título de página: 30pt bold, tracking −1,0, com sobretítulo `eyebrow` (`PageHeader`).
- `eyebrow`: 10,5pt mono medium, caixa alta, tracking +0,8. Usado em rótulos, "TODAY", status.
- Número grande: 30pt rounded semibold, tracking −0,9, dígitos tabulares (`BigValue`). Legenda dos anéis: 22pt, tracking −0,5.
- Título de cartão: subheadline semibold, tracking −0,1, na cor do assunto. Apoio: callout cinza; rodapé: caption cinza.
- Todo número com `monospacedDigit`.

## Espaço e forma
- Raio por papel (`Theme.Radius`): controle 8, cartão 18, painel 22. Padding de cartão 16, espaço entre cartões 16, página com padding 24 e largura máxima 1040.

## Movimento (`Motion`)
- Curva única `timingCurve(0.22, 1, 0.36, 1)`: instant 0,12 s, fast 0,16 s, regular 0,24 s, considered 0,48 s. Saída `(0.7, 0, 0.84, 0)` 0,12 s.
- Anéis fecham do zero ao valor ao aparecer (0,48 s). Cartão clicável: sobe no hover, escala 0,98 ao pressionar, anel de foco com respiro.
- Tudo passa por `.motion(_:value:)`, que desliga com "Reduzir movimento".

## Estados
Carregando: `LoadingPage` com skeleton e brilho. Vazio: `EmptyPage`/`EmptyNote`. Erro do GitHub: cartão laranja com o texto selecionável e "mostrando os últimos dados salvos".

## Voz e conteúdo
- Inglês original, português como opção, sempre lado a lado em `T("…", "…")`.
- Frases curtas, fatos concretos, sem jargão quando dá. Erro diz o que fazer.
- Números: en `598M`, `1.2B`, `35K`, `4h 06m`, `$277.45`; pt `598 mi`, `1,2 bi`, `35 mil`, `4h 06min`, `US$ 277,45` (`Fmt`).
