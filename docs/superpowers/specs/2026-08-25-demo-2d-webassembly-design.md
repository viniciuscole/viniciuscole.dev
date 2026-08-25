# Demo jogável do jogo 2D em C++/OpenGL — WebAssembly nativo

**Data:** 2026-08-25
**Status:** aprovado para planejamento
**Specs anteriores:**
`docs/superpowers/specs/2026-08-16-viniciuscole-dev-site-design.md` (Fase 1),
`docs/superpowers/specs/2026-08-17-demo-jogo-fase-2-design.md` (Fase 2)

## Objetivo

Fazer o [2D-Computer-Graphics](https://github.com/viniciuscole/2D-Computer-Graphics)
— um jogo de rolagem lateral em C++ com OpenGL/GLUT, trabalho da disciplina de
Computação Gráfica (UFES, 2024-2) — rodar jogável dentro da página do projeto,
compilado para WebAssembly com Emscripten.

Diferença essencial em relação à Fase 2: **aqui não há emulador**. O jogo da
velha roda dentro do DOSBox compilado para WebAssembly, 2,1 MB de emulador
executando um binário DOS de 3 KB. Este roda nativo: os 181 KB de `.wasm` **são**
o C++ do projeto, compilado. É a segunda prova do mecanismo da Fase 1, por um
caminho tecnicamente oposto.

## O que já foi verificado na prática

Nada aqui é suposição. Tudo abaixo foi compilado e executado em navegador de
verdade (Chromium com SwiftShader, imagem `mcr.microsoft.com/playwright:v1.56.0-noble`)
antes desta spec ser escrita.

### Compila, linka e roda

A linha de compilação abaixo produz artefatos funcionais:

```
em++ -std=c++11 -O2 main.cpp arena.cpp tinyxml2.cpp character.cpp hero.cpp \
     enemy.cpp shot.cpp \
     -sLEGACY_GL_EMULATION=1 -sALLOW_MEMORY_GROWTH=1 -sEXIT_RUNTIME=0 \
     -lGL -lglut --preload-file arena_teste.svg -o jogo.js
```

| artefato | bytes |
|---|---|
| `jogo.wasm` | 181.115 |
| `jogo.js` | 195.621 |
| `jogo.data` (arena SVG embutida) | 2.816 |
| **total** | **~379 KB** |

Note que `player.cpp` **não** entra na compilação e o link fecha mesmo assim.

### Linkar não é rodar — a lição mais cara deste probe

A primeira compilação linkou limpa e eu quase registrei "o OpenGL em modo
imediato passou". Não passou. No navegador o runtime abortava no primeiro
quadro:

```
Aborted(unsupported immediate mode 9)
```

Modo 9 é `GL_POLYGON`, usado em `circle.h:17` para desenhar os círculos
(cabeças dos personagens). A emulação legada do Emscripten não o implementa.

**Consequência para o plano de testes:** nenhum teste estático — compilação,
link, tamanho de artefato, presença de arquivo — teria pego isso. Só abrir num
navegador pega. Ver a seção *Verificação*.

### Símbolos que o Emscripten não tem

Três, todos de fonte bitmap do GLUT:

```
glRasterPos2f    glutBitmapCharacter    glutBitmapHelvetica18
```

Usados em exatamente dois lugares (`main.cpp:163` e `main.cpp:180`): as
mensagens de fim de jogo. Com eles stubados, **a tela de fim de jogo fica
inteiramente preta** — verificado. Ela era só texto.

O enunciado exige essa mensagem: *"Uma mensagem deverá ser exibida no centro da
tela indicando se o jogador ganhou ou perdeu."* Portanto o overlay em HTML não
é enfeite: sem ele o port perde um requisito avaliado.

### O jogo responde

Com o `GL_POLYGON` trocado por `GL_TRIANGLE_FAN` (idêntico para polígono
convexo), verificado em navegador:

- a arena, as plataformas, os obstáculos e o herói desenham
- `A`/`D` andam, com animação de pernas, e a câmera acompanha
- o mouse gira o braço; o botão esquerdo atira
- o botão direito pula, com altura proporcional ao tempo segurado
- `R` reinicia e devolve herói e câmera ao início
- `,` e `.` forçam derrota e vitória

### O menu de contexto e o pulo convivem

Suprimir o menu do navegador **não** quebra o pulo: o Emscripten recebe o
`mousedown` independentemente do evento `contextmenu`. Verificado — menu
cancelado (`dispatchEvent` devolveu `false`) e o herói subiu no mesmo teste.

### Medidas de altura do pulo

Medidas achando o pixel verde mais alto do quadro (ler o canvas WebGL direto
devolve preto, porque o drawing buffer não é preservado; o caminho correto é
screenshot → `<img>` → canvas 2D → `getImageData`):

| ação | pico |
|---|---|
| `W` tocado (120 ms) | 21 px acima do chão |
| `W` segurado (900 ms) | 147 px |
| botão direito segurado (900 ms) | 137 px |

O toque curto aterrissa em menos de 90 ms — uma medição feita 250 ms depois de
soltar registra zero e parece falha quando não é.

### A arena não é vazia

`arena_teste.svg` é uma fase completa: 364 unidades de largura contra ~40
visíveis (nove telas), 7 oponentes, plataformas e obstáculos. O herói nasce na
ponta esquerda, por isso um screenshot inicial mostra pouca coisa.

### Procedência

- O repositório **não tem arquivo de licença**, e o README tem uma linha (o
  título). A página do site será a primeira descrição real do projeto.
- Ele vendoriza o **tinyxml2** (licença zlib), que precisa de crédito na página.
- Data: o enunciado é `CG 2024-2`, último commit em 2025-01-27. Ano: **2024**.

## O que o enunciado exige (e por que isso decide o design)

O PDF do trabalho está no repositório (`24-11-28 CG 2024-2 - T2D.pdf`) e
resolve três dúvidas que pareciam questão de gosto:

**A janela é 500x500 por exigência.** *"A janela de visualização será quadrada
(com altura e largura iguais a menor dimensão da arena) e será exibida em uma
janela de 500x500 pixel do sistema operacional. (...) Não é necessário tratar o
resize."* Alargar para 16:9 desviaria da especificação avaliada.

**O pulo é no botão direito por exigência.** *"ao apertar o botão direito do
mouse em qualquer lugar da arena, ele deverá pular (...) se o botão de pular for
liberado antes de atingir a altura máxima, o jogador deverá começar a descer."*
Não foi escolha arbitrária do autor.

**As teclas `n`, `t`, `l`, `,` e `.` são roteiro de apresentação, não debug.**
*"Pontos só serão dados para funcionalidades apresentadas (...) Cabe aos alunos,
portanto, criarem atalhos (para habilitar e desabilitar funcionalidades, por
exemplo, movimento do oponente) no trabalho para facilitar a apresentação."*
Cada uma prova um item da tabela de pontuação; `l` injeta 10 milhões de
iterações por quadro para demonstrar independência de taxa de quadros, exigida
no item "Geral".

**`W` nunca foi o pulo.** `keyStatus['w']` é marcado em `main.cpp:231` e nunca
lido — resto de uma tentativa anterior ao enunciado.

## Decisões tomadas

| # | decisão | escolha |
|---|---|---|
| 1 | Onde vivem as mudanças no C++ | Patches neste repositório, sobre clone raso do upstream |
| 2 | Celular / toque | Sem controles virtuais e sem detecção de toque; só a legenda em HTML |
| 3 | Enquadramento | 500x500 mantido (exigência do enunciado) |
| 4 | Teclas de apresentação na página | Não expor nenhuma |
| 5 | Menu de contexto | Suprimir sobre o canvas |
| 6 | Pulo no `W` | Acrescentar, mantendo o botão direito |
| 7 | `ESC` (hoje `exit(0)`) | **Proposta, pendente de revisão:** neutralizar |

A decisão 6 é aditiva: o botão direito continua funcionando exatamente como o
enunciado exige, então o port não perde conformidade — ganha uma alternativa
confortável para quem joga em trackpad.

A decisão 7 é a única que **remove** comportamento, e por isso é a única que
proponho em vez de registrar como fechada. Detalhes e justificativa no patch
`0003`.

## Arquitetura

### Construção

```
build/2d/
  Dockerfile                    # FROM emscripten/emsdk, tag fixada
  0001-triangle-fan.patch
  0002-fim-de-jogo-em-html.patch
  0003-w-pula-e-esc-neutralizado.patch
```

Task `rake demo2d:build`, com a mesma forma do `game:build` já existente:
clone raso do upstream **num SHA fixo**, `git apply`, `docker run` com
`--user $UID:$GID` (sem isso o artefato nasce root e a build seguinte exige
sudo), saída em `src/demos/2d-graphics/`.

Fixar o SHA é o que protege o patch: um `main` que andou não faz o patch aplicar
torto em silêncio. `git apply` que falha **derruba a task** — nunca segue sem o
patch, o que produziria um `.wasm` que aborta no primeiro círculo desenhado.

Como no jogo em assembly, **os artefatos são commitados e a task fica fora do
`rake check`**: quem clona o site não precisa de Docker nem de Emscripten, e o
CI não baixa a toolchain.

À linha de compilação verificada, acrescentam-se:

- `-sMODULARIZE=1 -sEXPORT_NAME=criarJogo2D` — para o módulo não subir sozinho
  ao carregar o script, permitindo o padrão "carrega sob clique"
- `-sEXPORTED_FUNCTIONS=['_main','_reiniciarDoNavegador']`
- `-sEXPORTED_RUNTIME_METHODS=['ccall']`

**Nenhum desses três foi verificado.** É a primeira tarefa do plano.

### Os três patches

**`0001-triangle-fan.patch`** — uma palavra em `circle.h`: `GL_POLYGON` →
`GL_TRIANGLE_FAN`. Desenha idêntico para polígono convexo, e sem isso o runtime
aborta.

**`0002-fim-de-jogo-em-html.patch`** — substitui os dois laços de
`glutBitmapCharacter` por um aviso ao navegador, e expõe o reinício:

```cpp
EM_ASM({ if (window.__jogo2d) window.__jogo2d.fim($0); }, gameWon ? 1 : 0);
...
extern "C" EMSCRIPTEN_KEEPALIVE void reiniciarDoNavegador() { restartGame(); }
```

Semanticamente o mesmo que o original: onde o C++ desenhava texto no centro da
tela, agora pede à página que mostre texto no centro da tela — traduzido e no
tipo do site. O `EM_ASM` é chamado a cada quadro enquanto o jogo está acabado,
então o lado JavaScript precisa ser idempotente.

`reiniciarDoNavegador` existe para o botão "jogar de novo" não depender de
`KeyboardEvent` sintético — foi exatamente aí que o teclado do js-dos deu
trabalho na Fase 2. Chamar a função exportada não tem como falhar em silêncio.

**`0003-w-pula-e-esc-neutralizado.patch`** — duas mudanças pequenas:

```cpp
case 'w': case 'W':
    keyStatus[(int)('w')] = 1;
    player.jump();            // acrescentado
    break;
```
```cpp
void keyup(unsigned char key, int x, int y) {
    keyStatus[(int)(key)] = 0;
    if (key == 'w' || key == 'W') player.stopJump();   // acrescentado
    glutPostRedisplay();
}
```

`jump()` já se protege com `if (!isJumping && !isFalling)`, então a repetição de
tecla ao segurar `W` é inofensiva, e `stopJump()` no `keyup` dá o controle de
altura de graça. Medidas na seção anterior.

A segunda mudança **neutraliza o `ESC`**, hoje `exit(0)` em `main.cpp`. Num
executável de desktop sair é razoável; numa página não existe "sair", e um
visitante que encoste no `ESC` fica com um canvas morto e nenhum caminho de
volta além de recarregar. O `ESC` não é exigido pelo enunciado.
**Ponto para sua revisão** — é a única mudança aqui que remove comportamento em
vez de acrescentar.

### Front-end

**`src/_partials/demos/_wasm.erb`** — mesma anatomia do `_jsdos.erb`: quadro com
botão que nasce `disabled` (sem JavaScript o clique não faz nada; o player
habilita quando está pronto), canvas oculto até bootar, parágrafo de erro com
tempo limite de 30 s, `<noscript>` apontando para o repositório. Dois elementos
novos:

- **a legenda**, em HTML traduzido: `A`/`D` andar, **segurar o botão direito ou
  `W`** para pular (com a altura variando conforme o tempo), botão esquerdo
  atirar, mouse mirar, `R` recomeçar. Nenhuma tecla de apresentação (decisão 4).
- **o overlay de fim de jogo**, oculto, centrado sobre o canvas: a mensagem e um
  botão "jogar de novo" que chama `reiniciarDoNavegador` via `ccall`.

**`plugins/builders/demo_helper.rb`** — acrescentar `"wasm"` a `DEMO_TYPES`.
Nenhuma outra mudança no dispatcher.

**`frontend/javascript/wasm-player.js`** — boota sob clique, carrega
`/demos/2d-graphics/jogo.js`, instancia o módulo com `canvas` e
`arguments: ["arena_teste.svg"]` (verificado: é assim que `argv[1]` chega ao
`main`), instala `window.__jogo2d.fim()`, suprime `contextmenu` sobre o canvas,
dá foco ao canvas ao bootar, e revela o erro se nada subir em 30 s.

**Estilos.** `.demo-frame`, `.demo-start`, `.demo-error`, `.demo-weight` e
`.demo-license` vivem hoje em `crt.css`, que é o tratamento de CRT do jogo DOS.
Este jogo não é CRT — fingir fósforo verde nele seria mentira estética.
Extrair o casco compartilhado para `demo.css`, deixar `crt.css` só com o que é
CRT, e criar `wasm-demo.css` para o novo.

**Traduções.** Hoje `demo.weight` diz "carrega um emulador DOS, ~2,1 MB" e
`demo.commands.*` fala de jogo da velha, tudo no nível de cima. Com dois tipos
isso vira ambiguidade: mover o que é específico para `demo.jsdos.*` e
`demo.wasm.*`, mantendo em `demo.*` só o comum (`label`, `start`, `failed`,
`noscript`, `missing_bundle`).

Nenhuma das duas é refatoração gratuita — são costuras que o primeiro tipo podia
deixar implícitas e o segundo não.

### Conteúdo

`src/_projects/2d-graphics.en.md` e `.pt.md`:

```yaml
slug: 2d-graphics
year: 2024
featured: true
order: 2
tech: [C++, OpenGL, GLUT, Emscripten, WebAssembly]
repo: https://github.com/viniciuscole/2D-Computer-Graphics
demo:
  type: wasm
  base: /demos/2d-graphics/jogo
```

`base` em vez de `bundle` porque o Emscripten produz um trio com prefixo comum,
não um arquivo único.

O corpo, nos dois idiomas: o que o trabalho faz, a arena lida de SVG, os
personagens articulados desenhados a partir de um círculo, e o que custou
portar — sem inflar. Crédito ao tinyxml2 (zlib).

## Verificação

### No `rake check`

Testes estáticos, sem Docker e sem navegador:

- o partial renderiza todos os ganchos com `type: wasm`
- `DEMO_TYPES` aceita `wasm`; tipo desconhecido continua degradando para `none`
- **os três artefatos existem e têm tamanho plausível** — guarda direto contra o
  defeito da Fase 2, onde a vendorização esqueceu três arquivos e a demo não
  bootava com a suíte verde
- os três chegam ao **output** do build, não só ao `src/` — a lição do Node 20,
  onde o site publicou `MISSING_ESBUILD_ASSET` com tudo verde
- a legenda não menciona nenhuma tecla de apresentação (falha se `n`, `t`, `l`,
  `,` ou `.` vazarem para a página)
- a reorganização das traduções não deixou chave órfã no `_jsdos.erb`
- contraste WCAG de qualquer cor nova, no molde de `crt_test.rb`

Cada um provado por remoção: apagar o que ele guarda, ver a suíte ficar
vermelha. Teste que não sei fazer falhar não é teste.

### Fora do `rake check`: `rake demo2d:verify`

O aparato usado neste probe, promovido a task permanente: sobe o site, abre o
Chromium na imagem do Playwright e afirma o que foi afirmado à mão —

- o canvas desenha (pixels não pretos no screenshot, não via `readPixels`)
- `A`/`D` mudam o quadro
- `W` e o botão direito levantam o herói, e segurar sobe mais que tocar
- o `contextmenu` é cancelado
- o overlay de fim de jogo aparece ao forçar vitória
- o botão de reiniciar devolve o jogo

Não é ferramenta descartável: é o único instrumento capaz de pegar uma regressão
como o `GL_POLYGON`, que compilava, linkava e abortava no primeiro quadro.

### Verificação humana

Abrir e jogar. O Chromium headless com SwiftShader prova que desenha e responde;
não prova jogabilidade nem taxa de quadros em GPU real.

## Riscos

| risco | mitigação |
|---|---|
| `MODULARIZE` não verificado | Primeira tarefa do plano, com o aparato de navegador |
| Patch para de aplicar | SHA fixo do upstream; `git apply` que falha derruba a build |
| Emulação legada de GL é instável por natureza (o próprio Emscripten avisa no console) | `demo2d:verify` a cada reconstrução |
| 379 KB baixados no celular sem o jogo ser jogável | Carrega só sob clique; a legenda sinaliza teclado e mouse (decisão 2, custo aceito) |

## Fora de escopo

- Controles virtuais para toque
- Tratar `resize` (o enunciado dispensa)
- Arenas alternativas
- Alterar o upstream
- Expor as teclas de apresentação

## Descartável deste probe

Os stubs de texto (`shim_texto.cpp`), o `index.html` de teste e os scripts
`verifica.js` / `curto.js` foram instrumentos de medição. As medidas viraram
esta spec; o código não entra no repositório. O que sobrevive é o conteúdo dos
patches e o desenho do `demo2d:verify`.
