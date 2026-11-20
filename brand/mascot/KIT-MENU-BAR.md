# GitBeat · Mascote na barra de menus

## O que está pronto

A versão v2 corrige os sorrisos de **Por perto**, **Em foco** e **Boas-vindas**. Também corrige a causa da deformação nas animações SVG: a rotação dos olhos e a transformação da piscada agora ficam em grupos separados. A aplicação de `transform-origin` na animação não reposiciona mais o grupo que já contém uma matriz de rotação. As poses Conquista, Pausa e Novidade mantêm seus desenhos.

Há uma versão monocromática simplificada para o espaço da barra de menus: ela usa o mesmo corpo do cursor e um rosto com recortes transparentes. A cor fica a cargo do AppKit (`NSImage.isTemplate = true`), para funcionar tanto em barras claras quanto escuras. Não é uma miniatura colorida com detalhes ilegíveis.

## Testar visualmente

- `preview.html`: galeria corrigida com um controle deslizante para simular consumo na barra de menus. Os totais exibidos são ilustrativos.
- `menu-bar/preview.png`: amostra estática das cinco situações em fundos claro e escuro.
- `demo/run-preview.command`: compila e abre uma prévia nativa a partir do código Swift incluído, usando as ferramentas de desenvolvimento do Mac. Cria **um item separado** na barra, com o total simulado 96.5M. Clique nele para escolher os ritmos. O menu é identificado como **PRÉVIA — dados simulados**. Use **Encerrar prévia** para removê-lo.
- `demo/MenuBarPreview.swift`: código-fonte do aplicativo de prévia. Ele não se conecta ao GitBeat, não acessa GitHub e não coleta dados. O código foi compilado localmente; a entrega inclui o código-fonte e o lançador, sem um instalador ou uma distribuição do produto.

O app real instalado não foi modificado. O repositório fornecido retornou 404 pelo conector nesta sessão. A ligação aos dados reais precisa ocorrer no código-fonte do GitBeat.

## Comportamento sugerido e implementado

**O número mostra o total; o movimento mostra a atividade recente.** Usar o total acumulado para acelerar o personagem o deixaria agitado pelo resto do dia.

O módulo calcula os incrementos do contador observados numa janela móvel de 60 segundos:

| Situação | Faixa padrão | Visual |
| --- | --- | --- |
| `idle` | Nenhum incremento recente | Quietinho, sem animação contínua |
| `flowing` | Mais de 0 e menos de 100 mil tokens | Movimento leve, ciclo de 3 s |
| `busy` | De 100 mil a menos de 500 mil tokens | Movimento atento, ciclo de 2 s |
| `burst` | 500 mil tokens ou mais | Movimento mais rápido, ciclo de 1,25 s |
| `paused` | Pausa explícita | Olhos fechados, estático |

As faixas são valores de exemplo, configuráveis. O mascote acompanha a atividade; não há comemoração automática por gastar mais tokens. Uma espera mínima de 2 segundos entre mudanças de estados ativos evita oscilações rápidas perto dos limiares. Quando os incrementos expiram, ele volta a ficar quieto.

O primeiro total recebido estabelece uma base: abrir o app já com 96.5M tokens não dispara uma animação intensa. Quando o contador zera ou diminui (por exemplo, na virada do dia), o histórico é reiniciado. Amostras fora de ordem ou negativas são ignoradas. Lacunas maiores que a janela estabelecem uma nova base, pois o módulo não pode saber quanto daquele consumo ocorreu no último minuto.

## Integração no GitBeat real

1. Adicione `integration/GitBeatActivityMeter.swift` e `integration/GitBeatMenuBarController.swift` ao target macOS.
2. Copie a pasta `macOS/GitBeatMenuBarAnimations` como recurso, preservando os subdiretórios (`idle/000@2x.png`, `flowing/000@2x.png`, etc.).
3. Guarde uma referência forte ao controller no ciclo de vida do app. Se o app já possui um `NSStatusItem`, passe esse item para reutilizá-lo e preservar seu menu.
4. Encaminhe para `update(totalTokens:)` **a mesma série cumulativa** que alimenta o número atual da barra, idealmente a cada poucos segundos. Não envie a soma diária e depois o total vitalício: são séries diferentes.

```swift
// Executar na MainActor. Guardar como propriedade, não como variável temporária.
var config = GitBeatActivityMeter.Configuration()
config.busyTokens = 100_000
config.burstTokens = 500_000

let mascotBar = GitBeatMenuBarController(
    statusItem: existingStatusItem,
    configuration: config
)

// Sempre que o tracker existente entregar um novo snapshot:
mascotBar.update(totalTokens: snapshotTotalTokens)

// Se o usuário pausar o acompanhamento:
mascotBar.setPaused(true)

// Para retomar:
mascotBar.setPaused(false)

// Se não houver menu associado ao item, o clique pode abrir o app:
mascotBar.onOpen = { /* abrir a janela principal do GitBeat */ }

// No encerramento do app:
mascotBar.invalidate() // mantém o status item de propriedade do app
```

O controller é `@MainActor`; faça o encaminhamento para a MainActor se os snapshots chegam de uma tarefa em segundo plano. Não atualize simultaneamente a imagem/título do mesmo botão em outro timer: faça o controller cuidar da apresentação do item, mantendo a coleta de dados no tracker existente.

## Movimento e custo

- Máximo de **8 quadros por segundo**, suficiente para movimentos pequenos nesse tamanho.
- Ícones pré-carregados de **36 × 36 px**, apresentados como **18 × 18 pt** em telas 2x.
- Em repouso e em Reduzir Movimento, o timer faz apenas manutenção de estado a cada segundo e não troca a imagem desnecessariamente.
- Ao colocar o Mac em repouso, o timer para. No retorno, o histórico recente é limpo e os dados seguintes estabelecem o novo ritmo.
- Reduzir Movimento é observado em tempo de execução, mantendo o estado visual estático e o contador funcionando.
- Se os recursos não forem encontrados, usa o template estático do catálogo ou o símbolo de cursor do sistema.

## Executar a prévia nativa

Abra `demo/run-preview.command` ou execute no Terminal, a partir da pasta do kit:

```sh
./demo/run-preview.command
```

O lançador usa `swiftc` para compilar os três arquivos de código incluídos em uma pasta temporária e inicia a prévia com o caminho explícito dos frames. Não instala nem substitui o GitBeat. Requer ferramentas de desenvolvimento Swift disponíveis no Mac. O menu da prévia inclui **Encerrar prévia**.

## Verificação

O cálculo da atividade foi exercitado com testes determinísticos: total inicial, faixas, expiração, reset diário, pausa, entradas inválidas, amostras fora de ordem, lacunas na coleta e tempo mínimo entre estados. Os módulos passaram pelo compilador Swift e a prévia nativa foi compilada. Isso não substitui o teste da ligação ao tracker real dentro do GitBeat.
