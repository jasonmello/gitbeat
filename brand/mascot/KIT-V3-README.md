# GitBeat · Artes e movimento v3

Este pacote contém somente ilustrações, animações e metadados de reprodução. Não instala nem modifica o aplicativo. A programação permanece na sessão do Claude.

Abra `preview.html` para comparar as novas animações da barra em 18 e 20 pt, com detalhe ampliado, e reproduzir os quatro momentos do mascote dentro do app.

## Dentro do app: os quatro estados já estão aqui

| Estado | Pasta | Reprodução | Uso visual previsto |
| --- | --- | --- | --- |
| Boas-vindas | `greeting` | 30 quadros, 1,25 s, uma vez | Ao abrir a janela |
| Foco | `focus` | 58 quadros, aproximadamente 2,42 s, loop | Enquanto as ferramentas monitoradas registram atividade |
| Pausa | `rest` | 144 quadros, 6 s, loop | Depois de um período sem atividade |
| Comemoração | `success` | 30 quadros, 1,25 s, uma vez | Quando os três anéis passam de incompletos para completos |

Também acompanham `idle` (por perto) e a pose estática `curious` (novidade). Foram mantidos o mascote aprovado e os sorrisos corrigidos da v2. A correção de separar a rotação dos olhos da transformação da piscada está nos SVGs animados.

Em `app/`:

- `svg/`: poses estáticas em vetor, sem bitmap embutido.
- `animated-svg/`: animações vetoriais para ferramentas web compatíveis.
- `apng/`: prévias animadas transparentes, com extensão `.png`.
- `frames/<estado>/`: quadros PNG transparentes de 256 × 256, a **24 fps**.
- `sprites/`: faixas horizontais com os mesmos quadros, 256 × 256 por quadro.
- `<estado>-static.png`: pose transparente de 512 × 512 para fallback e Reduzir Movimento.
- `animation-manifest.json`: número de quadros, duração, loop e caminhos.

As poses e os formatos do app foram organizados e conferidos, não ligados aos eventos reais por este pacote. As faixas horizontais longas podem ser substituídas pelas sequências de PNG quando a ferramenta de importação tiver limite de largura.

## Barra de menus: movimento redesenhado

O corpo, os olhos e os pezinhos agora participam do gesto. O personagem tem pausas entre as ações; não é só o ícone inteiro girando ou subindo.

| Estado | Gesto | Quadros | Duração |
| --- | --- | --- | --- |
| `idle` | Olhadinha e piscada ocasional; bastante repouso | 96 | 8 s |
| `flowing` | Olha para o trabalho, inclina suavemente e alterna os pezinhos | 72 | 6 s |
| `busy` | Passinhos mais rápidos e corpo acompanhando o ritmo | 36 | 3 s |
| `burst` | Dois saltinhos com aterrissagem macia, seguidos de intervalo | 36 | 3 s |
| `paused` | Olhos fechados, corpo tranquilo | 1 | Estático |

**Importante para importar: o menu v3 usa 12 fps e novas contagens de quadros.** Os limites da v2 (1/24/16/10) não servem. Copiar apenas os PNGs sem atualizar os tempos/contagens pode cortar os gestos e esconder a piscada. O mascote dentro do app continua a 24 fps.

Em `menu/`:

- `frames/<estado>/000.png`, etc.: tamanho lógico de **18 pt**, PNGs de 18 × 18 em 1x e 36 × 36 em `@2x`.
- `frames-20pt/`: opção de **20 pt**, PNGs de 20 × 20 e 40 × 40 em `@2x`. Alterar também o tamanho lógico no app ao escolher essa opção.
- `sprites/<estado>.png`: faixa horizontal dos quadros de 36 × 36.
- `svg/<estado>.svg`: reprodução vetorial da nova animação, para revisão em navegador compatível.
- `keyposes/`: quadros-chave em SVG independente para editar no Figma/Illustrator/Affinity.
- `apng/<estado>.png`: ampliação transparente para revisão.
- `previews/<estado>-dark.png` e `-light.png`: APNGs de uma barra ilustrativa.
- `previews/<estado>.gif`: GIFs com fundo sólido, somente para revisão rápida.
- `animation-manifest.json`: especificações para importar os quadros.

Os PNGs de produção do menu são pretos com alfa transparente; olhos e boca são recortes transparentes. O Claude deve tratá-los como **template do AppKit**, deixando o macOS aplicar a cor adequada ao fundo. Os GIFs com fundo e o número 96.5M são só demonstração; não usar como ícone real. O número não deve mover junto com o personagem.

## Direção de comportamento para a programação

- Boas-vindas: uma vez ao abrir, sem reiniciar ao trocar de seção.
- Foco: inferido da atividade realmente monitorada pelo app, sem prometer detectar toda programação.
- Pausa: ao encerrar a atividade, com um intervalo de tolerância para não piscar entre estados.
- Anéis fechados: uma vez por conclusão/dia. Não comemorar simplesmente porque o histórico já estava completo na primeira leitura nem porque uma meta foi editada.
- Barra: o texto mostra o total; a animação pode acompanhar a atividade recente. Mais tokens não são tratados como conquista.
- Reduzir Movimento: usar pose estática e manter contador/estados funcionando.
- Pausar a animação colorida quando a janela estiver oculta. A barra pode continuar refletindo o estado, com pequenos intervalos e sem redesenhar frames idênticos à toa.

Essas são instruções de uso da arte; a implementação e os gatilhos ficam no projeto do Claude.

## Fontes editáveis

Todos os SVGs são vetores reais. `source/vector-scenes.json` também descreve a geometria de todos os quadros da barra, com canvas de 512 unidades. `source/render.swift` gera os renders intermediários desses vetores via AppKit/CoreGraphics:

```sh
swift source/render.swift /caminho/absoluto/para/gitbeat-mascot-art-v3
```

Ele grava imagens intermediárias de 216 × 216 em `png/`; para os arquivos de produção, prefira os PNGs prontos nas pastas de frames. Os grupos e recortes são editáveis nos SVGs das poses-chave. Não houve alteração de marca, rosto ou paleta do personagem colorido.
