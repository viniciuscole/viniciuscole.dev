---
title: Jogo de Rolagem Lateral em C++ e OpenGL
locale: pt
slug: 2d-graphics
year: 2024
featured: true
order: 2
summary: Um jogo de rolagem lateral em C++ com OpenGL e GLUT, que lê sua arena de um arquivo SVG, compilado para WebAssembly para rodar aqui.
tech: [C++, OpenGL, GLUT, Emscripten, WebAssembly]
repo: https://github.com/viniciuscole/2D-Computer-Graphics
demo:
  type: wasm
  base: /demos/2d-graphics/jogo
---

O jogo lê a arena de um arquivo SVG: o retângulo azul é o campo, os
retângulos pretos são obstáculos, o círculo verde marca onde o jogador
começa e os vermelhos, os oponentes (sete deles). Os círculos servem só de
posição e escala — cada personagem é desenhado inteiro a partir dali, com
cabeça, tronco, braço articulado e duas pernas com quadril e joelho,
animadas ao andar. O braço acompanha o mouse.

A arena tem nove telas de largura; a janela quadrada acompanha o jogador na
horizontal. O objetivo é atravessar da esquerda para a direita sem ser
atingido.

Toda a renderização usa OpenGL em modo imediato — `glBegin`, `glVertex2f`,
`glOrtho` — e o SVG é lido com [tinyxml2](https://github.com/leethomason/tinyxml2)
(licença zlib), compilado junto.

## O que custou trazer para o navegador

O Emscripten compila o C++ para WebAssembly, mas não implementa tudo que o
GLUT oferece. Duas coisas precisaram mudar.

`GL_POLYGON`, usado para desenhar os círculos, não existe na emulação de
modo imediato: o programa compilava e linkava sem reclamar, e abortava no
primeiro quadro. Trocado por `GL_TRIANGLE_FAN`, que desenha exatamente o
mesmo para um polígono convexo.

As mensagens de fim de jogo eram desenhadas com fontes bitmap do GLUT, que
o Emscripten também não tem. Elas viraram HTML sobre o canvas — o que, de
quebra, as deixou traduzidas.

Os dois pontos entram no código dentro de blocos `#ifdef __EMSCRIPTEN__`, o
que deixou a compilação nativa intacta: o `make` do próprio trabalho ainda
produz o executável `trabalhocg`, e ali as mensagens continuam desenhadas
pelo GLUT, como sempre foram. O port não substituiu o original — ganhou um
segundo alvo.

Fora isso, o jogo aqui é o mesmo que roda nativo: os cerca de 180 KB de
WebAssembly desta página são o C++ do trabalho, compilado. Não há emulador
no meio.
