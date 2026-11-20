# DESIGN.md: GitBeat

Valores tirados de `Sources/GitBeat/Theme.swift`, `Sources/GitBeat/Brand.swift`, `Sources/GitBeat/Views/Components.swift`, `Sources/GitBeat/Views/MascotView.swift`, `Sources/GitBeat/MenuBarMascot.swift` e do `:root` de `site/index.html`. Mudou lá, mude aqui no mesmo PR.

## Princípios
- **Um companheiro, não um painel frio.** O mascote acompanha o dia: dá boas-vindas, fica junto enquanto você programa, descansa quando você para e comemora uma vez quando os anéis fecham. Nunca cobra produtividade, e consumir mais tokens não é conquista.
- **Número primeiro, explicação em uma linha.** Cada cartão responde uma pergunta ("how much today?"). Cartões com título colorido e ícone, número grande, gráfico embaixo; anéis para metas.
- **Honesto.** Custo é "equivalent at API prices"; o que é estimativa diz que é. About the data explica cada diferença que o usuário pode notar.
- **Nativo, do jeito do sistema.** Liquid Glass na camada que flutua sobre o conteúdo (barra lateral, barra de ferramentas, dica do gráfico, painel da barra de menu); o conteúdo fica em cartões sólidos, porque texto sobre vidro perde contraste. Clássico tira o vidro também da dica do gráfico e é o que aparece antes do macOS 26.
- **Cor nos dados, marca no clima.** As cores dos assuntos ficam nos anéis, barras e títulos dos cartões. A paleta do mascote (lavanda, ameixa, roxo, limão) fica no fundo, no destaque do sistema e no site. Rótulos de apoio, setas e "Today" em cinza.
- **Leve.** Animação só onde tem significado e só quando está à vista; o app fica perto de 0% de CPU parado (ver `docs/decisoes.md`).
- **Marca própria.** Nada de comparar com produtos de outras empresas ("Apple Health", "app Saúde", relógio) em texto, slogan ou código. Citar a plataforma para dizer onde o app roda (macOS, iCloud Drive, Xcode) pode.

## Marca: o mascote
- Nome: **GitBeat**. Um cursor creme (#FFF8E8 → sombra lilás #C9A6EB), rosto ameixa #42175F, bochechas pêssego #FFC8AA, pés lilás (#C8A6F4 → #9D72D4) e sola limão (#CBF85A). Kit em `brand/mascot/` (guias: `brand/mascot/KIT-README.md`, `brand/mascot/KIT-MENU-BAR.md`, `brand/mascot/KIT-V3-README.md`). Logo G anterior em `archive/brand-g/`.
- Preservar a silhueta, o rosto inclinado e a sola limão. Nada de acessórios ou símbolos de código no personagem.
- Ícone do app: placa roxa (#7634FF → #3810CD) com o mascote, pronto do kit (`Resources/AppIcon.icns`). Não redesenhar nem pôr moldura por cima.
- Logo = mascote + nome. Nome ameixa no claro (`Resources/logo-on-light.svg`), branco no escuro (`Resources/logo-on-dark.svg`), via `BrandLogo`: 32pt na barra lateral, 24pt no painel da barra de menu.
- Cores da marca no app: `Brand.violet` #7634FF, `Brand.violetDeep` #3810CD, `Brand.lime` #CBF85A, `Brand.plum` #42175F. Destaque do sistema (seleção, botões, chaves): `.tint(Brand.violet)` em todas as cenas. Destaque em texto e ícones pequenos (`Brand.accent`): roxo #5920F5 no claro, limão no escuro (limão não tem contraste em fundo claro).
- **Na janela** (`MascotView`, 24 fps, quadros de `Resources/Mascot/` cortados uma vez em imagens de 8 bits de 192 px): topo do Resumo (`SummaryMascot`, 92pt), tela de carregamento (idle, 56pt) e tela vazia (curious, parado, 96pt). Humor em `AppModel.mascotMood`: boas-vindas uma vez por abertura; comemoração uma vez por dia, só quando os anéis *passam* a fechar com o app aberto (não na primeira leitura nem ao editar meta); foco com atividade nos últimos 15 min; pausa depois de 2 h parado; senão, por perto. Para quando a janela não está ativa; "Reduzir movimento" mostra a pose parada.
- **Na barra de menu** (`MenuBarMascot`, kit v3: 12 fps, 18pt, PNG preto com recortes tratado como template do AppKit): o número mostra o total de hoje e não se mexe; o movimento mostra o ritmo dos últimos 3 min (`ActivityMeter`): quietinho, fluindo, ocupado, pico. Quadros idênticos seguidos viram um trecho só e o timer acorda só quando a imagem muda. Vira chama quando a sequência está em risco.
- Crédito: "Proudly developed by Jason Mello" (`CreditLine`), no rodapé da barra lateral, nos Ajustes, em About the data e no painel Sobre. **O nome é sempre um link para https://github.com/jasonmello** (`Brand.authorURL`), também no site e no README. No app: semibold na cor do texto, sublinha e mostra a mãozinha no hover.

## Cores dos assuntos (uma por assunto, em tudo daquele assunto)
| Assunto | Cor | Onde |
|---|---|---|
| Tokens | `Theme.tokens` = rosa suave #ef6288 | anel externo, gráficos de tokens |
| Tempo | `Theme.time` = azul-céu #3fa8d9 | anel do meio, tela Time |
| GitHub | `Theme.github` = verde #5fba4a, puxado ao limão da sola | anel interno, commits, quadriculado |
| Custo | `Theme.cost` = lilás #926def | custo equivalente, "by model" |
| Sequência | `Theme.streak` = pêssego #ee8d48 | chama, recorde, bolinhas da semana |

Tons médios e suaves, da família do mascote: a estrutura de uma cor por assunto continua, mas sem os tons saturados do sistema. Pastel claro não serve: some como texto sobre o creme.

## Neutros e texto (clima do kit do mascote)
Nunca preto ou branco puros: página `Theme.page` lavanda #f5f1fb / ameixa profundo #150d1e; cartão `Theme.raised` creme #fffaf3 / #221630; borda `Theme.hairline` lilás (a 14%) no claro, branco a 8% no escuro; trilhas `Theme.well` no ameixa a 7%. Sombra dos cartões em ameixa, não preto, no claro (`Theme.shadow`). Texto em `Theme.ink`: ameixa #42175f no claro, #f4effa no escuro, aplicado na raiz das cenas; `.secondary` e `.tertiary` derivam dele. Barras: hoje cheio com gradiente, outros dias com opacidade 0,45 e canto 4 (`MiniBars`). Trilha do anel: a cor do assunto a 0,2.

## Superfícies
- **Fundo** (`AppBackground`): só o neutro da página, sem manchas coloridas.
- **Cartão** (`cardSurface`): sólido, anel de 1px, luz de 1px no topo, sombra em duas camadas de alfa baixo (mais forte no escuro e no hover). Sombra só no fundo, nunca no conteúdo.
- **Flutuante** (`floatingSurface`): `glassEffect` no Liquid Glass; cartão sólido elevado no Clássico.
- **Painel da barra de menu** (`MenuBarView`): logo e data no topo; número na cor do texto, cor do assunto só no anel e no pontinho; sequência e custo em cápsulas `Theme.well`; botão "Open GitBeat" largo, em cápsula roxa (`borderedProminent` + `.capsule`), atualizar e sair como ícones sem borda.
- Tema: Automático, Claro ou Escuro (`Preferences.mode`).

## Tipografia
- Fonte do sistema em tudo (SF Pro; SF Pro Rounded nos números). Nada de mono no app.
- Título de página: 30pt heavy, tracking −1,0 (pesado e compacto, como o "GitBeat" do kit), com sobretítulo `eyebrow` (`PageHeader`).
- `eyebrow`: 11pt semibold, caixa alta, tracking +0,4, cinza ("DAILY AVERAGE", "TOKENS").
- Número grande: 32pt rounded bold, tracking −0,6 (`BigValue`); unidade em title3 rounded semibold cinza. Legenda dos anéis: 24pt rounded bold na cor do assunto, meta "/400M" na mesma cor a 75%.
- Título de cartão: headline na cor do assunto, ícone hierárquico. Rótulo à direita ("Today", "Week"): subheadline cinza; seta em cinza terciário. Apoio: callout cinza; rodapé: caption cinza.
- Todo número com `monospacedDigit`.

## Espaço e forma
- Raio por papel (`Theme.Radius`): controle 10, cartão 22, painel 28. Padding de cartão 18, espaço entre cartões 16, página com padding 24 e largura máxima 1040.

## Movimento (`Motion`)
- Curva única `timingCurve(0.22, 1, 0.36, 1)`: instant 0,12 s, fast 0,16 s, regular 0,24 s, considered 0,48 s. Saída `(0.7, 0, 0.84, 0)` 0,12 s.
- Anéis fecham do zero ao valor ao aparecer (0,48 s). Acima de 100% o anel dá outra volta por cima, e só a ponta faz sombra (até 300%). Volta fechada certinha (200%, 300%) não tem ponta.
- Resumo: anéis dos últimos 7 dias (`WeekRings`) quando cabem; semana em bolinhas na sequência (`StreakWeek`: cheia com check, hoje tracejado se ainda vazio). Cartão clicável: sobe no hover, escala 0,98 ao pressionar, anel de foco com respiro.
- Mascote: 24 fps na janela, 12 fps na barra; gestos de uma vez (boas-vindas, comemoração) param no último quadro.
- Tudo passa por `.motion(_:value:)` ou checa `accessibilityReduceMotion`, e para com "Reduzir movimento".

## Estados
Carregando: `LoadingPage` com skeleton e o mascote por perto. Vazio: `EmptyPage` com o mascote curioso; `EmptyNote` dentro de cartões. Erro do GitHub: texto selecionável e "mostrando os últimos dados salvos".

## Site (`site/index.html`)
- Mesma marca: paleta do mascote nos tokens do `:root`. Escuro (padrão) em ameixa profundo (`--bg` #120d18, superfícies #1a1422 → #2a2236, texto #f4effa); claro em lavanda (`--bg` #f6f2fc, cartões creme #fffaf3, superfícies #f3ecf8 → #e9dff3, texto ameixa #2b1340). Títulos peso 800, botões e chips em cápsula, raios 12/24/32. Cores de dado iguais às do app (`--pink`, `--cyan`, `--mint`, `--purple`, `--orange`). Claro e escuro seguem o sistema, com botão para trocar. Inglês original, botão PT.
- `--brand` (botões, foco, seleção, cápsula do idioma, coração do crédito): roxo #7440ff no escuro e #5e22ed no claro, texto branco. `--accent-text` (sobretítulos, destaque do título): limão #d8fa76 no escuro, roxo #5a1fe0 no claro. Brilhos de fundo em roxo, limão e rosa. `--mint` (#5fba4a) só para dados de commits.
- Cabeçalho com o logo do mascote (branco no escuro, ameixa no claro); favicon é o ícone do app. No topo, o mascote animado do kit (`site/assets/mascot-idle.svg`, respeita "reduzir movimento") no lugar da antiga linha de batimento.
- Imagem principal: a tela Resumo do app numa janela com os três botões, uma versão para cada tema. Imagens só de telas sem dados privados (Resumo, Tempo, Metas): nada de nomes de repositório, títulos de PR ou projetos. Gerar com `--snapshot`.
- Movimento: anéis fechando e barras subindo ao entrar na tela; tudo desliga com "reduzir movimento". Versão anterior guardada em `archive/site-2026-11-20/`.

## Voz e conteúdo
- Inglês original, português como opção, sempre lado a lado em `T("…", "…")`.
- Frases curtas, fatos concretos, sem jargão quando dá. Erro diz o que fazer. O mascote não fala em balões; o humor aparece no gesto e na descrição de acessibilidade.
- Notificações: título curto e uma frase com o número que importa ("Your 5-day streak ends today"). No máximo uma de anéis por dia e um lembrete de sequência.
- Números (`Fmt`): en `598M`, `1.2B`, `35K`, `4h 06m`; pt `598 mi`, `1,2 bi`, `35 mil`, `4h 06min`. Dinheiro na moeda escolhida nos Ajustes: en `$277.45` / `R$1,520.10`; pt `US$ 277,45` / `R$ 1.520,10`. O ícone do custo troca entre cifrão e real (`Fmt.costSymbol`).
