# GitBeat — kit do mascote cursor · v2

O companheiro de trabalho aprovado na conversa, redesenhado em curvas vetoriais: corpo creme, sombra lilás, rosto ameixa e um detalhe verde-lima no pezinho. A vetorização simplifica as curvas da imagem conceitual para facilitar o uso em interfaces; não é um recorte da imagem gerada.

## Atualização v2

Corrigidos os sorrisos e a transformação da piscada nas três poses reportadas. Incluídas animações nativas para a barra de menus, uma simulação por atividade recente de tokens e um app de prévia separado. Veja `MENU-BAR.md` para uso, configuração e ligação ao tracker real.

## Comece aqui

- Abra `preview.html` em um navegador para alternar os estados, repetir os gestos e testar fundos claros e escuros. Funciona sem dependências ou conexão.
- `preview.png`: apresentação visual das seis poses e teste de ícone pequeno.
- `svg/mascot-idle.svg`: arquivo principal, transparente e totalmente vetorial.
- `svg/gitbeat-logo-dark.svg` e `svg/gitbeat-logo-light.svg`: assinatura com **GitBeat**, com o nome convertido em curvas, sem depender de fonte instalada.
- `macOS/Assets.xcassets`: assets para importar no Xcode.
- `macOS/GitBeat.icns`: ícone macOS com múltiplas resoluções.

## Estados e uso proposto

| Arquivo/estado | Uso sugerido | Movimento entregue |
| --- | --- | --- |
| `idle` · Por perto | Tela inicial, resumo, acompanhamento normal | Respiração leve e uma piscada a cada ciclo de 4 s na sequência PNG |
| `focus` · Em foco | Sessão de trabalho em andamento | Inclinação e respiração curta, ciclo de 2,42 s |
| `success` · Conquista | Conclusão ou conquista escolhida pelo app | Pulinho de 1,25 s, executado uma vez |
| `rest` · Pausa | Pausa do usuário ou acompanhamento pausado | Olhos fechados e respiração lenta, ciclo de 6 s |
| `curious` · Novidade | Algo novo para explorar | Pose estática |
| `greeting` · Boas-vindas | Abertura do app | Balanço de 1,25 s, executado uma vez |

Esses estados são propostas visuais. O kit não lê atividades nem define automaticamente quando dispará-los. A integração com os eventos reais fica no aplicativo. Pausa deve parecer descanso, sem representar fracasso ou cobrar produtividade.

## Formatos

- **SVG:** arquivos editáveis, com caminhos e elipses reais. Sem bitmap embutido e sem dependências externas. Abra no Figma, Illustrator, Affinity ou editor de código. Os grupos `body`, `face`, `foot-left`, `foot-right`, `lime-sole`, `pose` e `float` facilitam a edição e o rig. Os olhos estão em grupos `.eye`.
- **PNG transparente:** estados em 256, 512 e 1024 px. O tamanho de 256 px é apropriado para uma exibição de até 128 pt em uma tela de escala 2x.
- **SVG animado:** cinco arquivos para web, WebView e demonstração; usam CSS e respeitam `prefers-reduced-motion`. As curvas vetoriais são as mesmas dos SVGs estáticos.
- **Sequências PNG:** cinco animações a 24 fps em `macOS/GitBeatAnimations/`, 256 × 256 px por frame. Adequadas ao exemplo SwiftUI fornecido.
- **Sprites:** uma faixa horizontal de frames por animação em `sprites/`; posições e duração em `animation-manifest.json`.
- **APNG:** prévias animadas em `apng/`, para ferramentas compatíveis. Elas continuam com extensão `.png`.
- **Ícones:** `.icns`, `.iconset`, `AppIcon.appiconset` e símbolo monocromático para a barra de menus.

Os loops SVG e as sequências raster compartilham o desenho e a intenção de movimento, mas não são sincronizados frame a frame. No PNG o personagem inteiro se move; no SVG o corpo é separado dos brilhos e os olhos piscam independentemente. A versão nativa de referência usa as sequências PNG.

## macOS / Xcode

### Ícone da Dock

Importe as entradas de `macOS/Assets.xcassets` para o catálogo existente do seu app. Se já houver um `AppIcon`, substitua seus arquivos de maneira controlada em vez de criar dois conjuntos com o mesmo nome. Selecione esse conjunto como o App Icon no target. O `AppIcon.appiconset` contém os dez arquivos tradicionais de macOS: 16, 32, 128, 256 e 512 pt, cada um em 1x e 2x, chegando a 1024 px.

Para ferramentas que recebem `.icns`, use `macOS/GitBeat.icns`. O PNG já contém a placa violeta arredondada e a margem externa; não acrescente outra moldura arredondada sobre ele. Este é um asset tradicional de macOS, não um arquivo de projeto do Icon Composer.

A recomendação visual é manter a Dock estática e usar as animações dentro do app. Os arquivos de ícone não ativam animações na Dock automaticamente.

### Barra de menus

O conjunto `GitBeatMenuBar.imageset` é monocromático, com intenção de renderização `template`. Inclui PNGs de 18 e 36 px. Exemplo SwiftUI:

```swift
Image("GitBeatMenuBar")
    .renderingMode(.template)
```

O sistema pode aplicar a cor apropriada à barra. Evite usar o ícone colorido completo nesse espaço pequeno.

### Mascote animado no app

1. Importe os seis conjuntos `Mascot-*.imageset` para o catálogo de assets.
2. Inclua a pasta `macOS/GitBeatAnimations` nos recursos do target, preservando a estrutura `GitBeatAnimations/idle/000.png`, etc. Verifique sua presença em Copy Bundle Resources. O player procura a pasta no bundle, sem achatar os arquivos.
3. Adicione `integration/GitBeatMascotView.swift` ao target. O exemplo se destina a macOS 13 ou superior.
4. Use:

```swift
GitBeatMascotView(mood: .idle)
    .frame(width: 128, height: 128)

GitBeatMascotView(
    mood: .success,
    isVisible: isMascotPanelVisible,
    replayID: celebrationCounter
)
.frame(width: 128, height: 128)
```

Aumente `celebrationCounter` para repetir um gesto sem mudar o estado. Use `isVisible: false` quando o painel estiver oculto. O exemplo deixa de agendar frames quando a cena não está ativa, respeita Reduzir Movimento e usa o PNG estático quando os frames não estão disponíveis. Gestos pontuais terminam no último frame e param de agendar atualizações.

É um exemplo de integração: o arquivo passou pela verificação de tipos do compilador Swift disponível, mas não foi integrado nem executado dentro do projeto GitBeat.

## Paleta e desenho

- Creme do corpo: `#FFF8E8` / `#FFF5E4`.
- Sombra do corpo: `#C9A6EB`.
- Olhos e boca: `#42175F`.
- Bochechas: `#FFC8AA`.
- Lilás dos pés: `#C8A6F4` → `#9D72D4`.
- Sola verde: `#E7FF96` → `#CBF85A`.
- Fundo do ícone: `#7634FF` → `#5920F5` → `#3810CD`.

Use `svg/mascot-flat.svg` quando precisar de cores sólidas. Preserve a silhueta, o rosto inclinado e a pequena sola verde: são os detalhes que mantêm o personagem consistente. Não adicione símbolos de código ou acessórios para explicar a marca. No menor ícone, o rosto e a silhueta são mais importantes que as bochechas ou a sola.

## Fonte vetorial e verificação

`source/vector-scenes.json` descreve os caminhos, cores e poses. `source/render.swift` permite renderizar esses mesmos vetores em PNG usando AppKit/CoreGraphics, sem dependências de terceiros:

```sh
swift source/render.swift /caminho/absoluto/para/gitbeat-mascot-kit
```

O renderizador exporta as cenas-base para `png/`; ele não recria sozinho os derivados, sprites ou o catálogo do Xcode. Os SVGs são independentes e podem ser editados diretamente.

Verificações realizadas: renderização visual dos estados, galeria no navegador com carregamento das imagens, XML dos SVGs, dimensões e transparência dos PNGs, referências do catálogo, frames/timing do manifesto, decodificação do ICNS e verificação de tipos do exemplo SwiftUI. O ícone ainda deve ser avaliado no app real e na Dock do usuário.
