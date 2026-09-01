---
title: Jogo 3D em C++ e OpenGL
locale: pt
slug: 3d-graphics
year: 2024
featured: true
order: 3
summary: A evolução em três dimensões do jogo anterior, com lanterna, minimapa e a mesma arena em SVG — mostrada aqui em vídeo, porque a emulação de OpenGL do navegador não sustenta sua iluminação.
tech: [C++, OpenGL, GLUT, GLU]
repo: https://github.com/viniciuscole/3D-Computer-Graphics
demo:
  type: video
  base: /demos/3d-graphics/jogo3d
---

É o mesmo jogo do projeto anterior, evoluído para três dimensões: a arena
continua lida de um arquivo SVG, ainda com
[tinyxml2](https://github.com/leethomason/tinyxml2) fazendo o parse, e as
mesmas classes de personagem — herói, inimigo e tiro — agora desenhadas em
profundidade.

A renderização usa OpenGL em modo de função fixa: três luzes, materiais,
texturas e teste de profundidade. Uma das luzes é uma lanterna presa ao
braço do jogador — há um modo em que as luzes ambientes se apagam e só ela
ilumina a cena. Os personagens são feitos de esferas (quádricas do GLU) e
prismas; um minimapa marca a posição do jogador dentro da arena.

## Por que esta página só tem vídeo

A emulação de OpenGL de função fixa do Emscripten não implementa
`GL_SPOT_CUTOFF`, `GL_SPOT_EXPONENT` nem `GL_SPOT_DIRECTION` — os parâmetros
que transformam uma luz posicional em um cone, ou seja, o modo lanterna. O
jogo compila e linka sem reclamar; a tela fica preta assim que o holofote
entra em cena, mesmo desligando-o nos outros momentos do jogo.

A investigação achou mais duas coisas, que valem registro por serem
honestas: as texturas eram 30 MB de BMP sem compressão (2000×2000 e
3000×2000 pixels, para uma janela de 500×500), e o carregamento delas
acontece antes de existir contexto OpenGL — nativamente os drivers toleram
isso, no navegador quebra.

Reescrever o desenho para shaders resolveria a lanterna, mas
descaracterizaria o argumento das outras demos deste site: que o que roda
ali é o código do trabalho, compilado, não uma reescrita para caber no
navegador. Então, neste projeto, você assiste em vez de jogar.
