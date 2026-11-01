---
layout: post
title: "Linkar não é rodar: um jogo C++ com OpenGL no navegador"
locale: pt
slug: linking-is-not-running
date: 2026-11-01
tags: [webassembly, opengl, testing]
---

O [jogo de rolagem lateral](/pt/projects/2d-graphics/) deste site foi um
trabalho de Computação Gráfica: C++, OpenGL em modo imediato, GLUT e uma arena
lida de um arquivo SVG. Portar ele foi o oposto do
[port do jogo da velha](/pt/2026/08/16/porting-dos-assembly-to-the-browser/).
Lá, um emulador de 1,4 MB roda um programa DOS de 3 KB. Aqui não tem emulador:
os 181.051 bytes do `jogo.wasm` são o meu C++, compilado pelo Emscripten.

Compilar foi um comando só:

```
em++ -std=c++11 -O2 main.cpp arena.cpp tinyxml2.cpp character.cpp \
     hero.cpp enemy.cpp shot.cpp \
     -sLEGACY_GL_EMULATION=1 -lGL -lglut \
     --preload-file arena_teste.svg -o jogo.js
```

Linkou limpo. Eu quase anotei "OpenGL em modo imediato funciona". Aí abri no
navegador e o jogo morreu no primeiro quadro:

```
Aborted(unsupported immediate mode 9)
```

Modo 9 é `GL_POLYGON`, que o jogo usa para desenhar a cabeça de cada personagem.
A emulação do OpenGL antigo no Emscripten não implementa esse modo. A correção é
uma palavra, `GL_TRIANGLE_FAN`, que desenha a mesma coisa para uma forma
convexa.

Corrigir foi fácil. O que ficou comigo é que nenhuma verificação, tirando rodar
o programa, teria pegado o bug. O compilador aceitou. O linker aceitou. Os
arquivos de saída existiam e tinham tamanhos plausíveis. Tudo que eu conseguia
checar sem navegador passava, num programa que não desenhava um quadro sequer.

Então montei uma bancada: um script que abre o jogo num Chromium de verdade
(headless, dentro da imagem Docker do Playwright), aperta teclas, clica o mouse
e confere o que aparece na tela. Quase tudo que aprendi com esse port veio de a
bancada estar errada.

## Não dá para ler um canvas WebGL

A primeira pergunta da bancada é "desenhou alguma coisa?". O óbvio é ler os
pixels do canvas. Isso devolve preto, sempre, porque o WebGL joga fora o buffer
de desenho assim que o quadro vai para a tela, a menos que você peça o
contrário.

O que funciona é dar a volta longa. Tira um screenshot pelo Playwright, carrega
num `<img>`, desenha num canvas 2D e chama `getImageData`. Toda medida da
bancada passa por esse caminho.

## Um teste que passa com o teclado desligado

A primeira versão de "apertar D move o jogador" comparava dois screenshots do
canvas inteiro, um antes da tecla e outro depois, e passava se fossem
diferentes.

Eles são sempre diferentes. A arena tem sete inimigos que andam e atiram
sozinhos desde o primeiro quadro, então a imagem muda entre dois instantes
quaisquer, com ou sem teclado. O teste passaria com a entrada completamente
quebrada, o que é pior do que não ter teste, já que tudo depois dele confiava
nele.

A correção foi medir a coisa que deveria se mexer. O herói é o único verde na
tela, então a bancada acha o centro horizontal dos pixels verdes e afirma que D
empurra ele mais de 20 px para a direita e A traz de volta. E tem que medir
perto do ponto de partida: a câmera acompanha o herói, e depois de alguns
passos ele fica centralizado e o deslocamento na tela quase some.

O pulo tinha a própria armadilha de tempo. Um toque rápido no W levanta o herói
21 px e ele aterrissa em menos de 90 ms. Minha primeira medida rodava 250 ms
depois de soltar a tecla, via o herói no chão e acusava uma falha que não
existia. Segurar W por 900 ms chega a 147 px. Hoje a bancada tira três amostras
logo depois de soltar e fica com o ponto mais alto.

## `exit(0)` não sai

O jogo original fecha no ESC com `exit(0)`. No desktop, tudo bem. Numa página
não existe para onde sair, então o port transforma o ESC em nada. A bancada
conferia isso apertando ESC e vendo se o herói continuava visível.

Essa checagem não servia para nada, e só descobri quebrando a proteção de
propósito e recompilando. Com o `-sEXIT_RUNTIME=0` do Emscripten, `exit(0)` não
para coisa nenhuma. Ele lança uma exceção `ExitStatus` não capturada dentro do
handler de tecla, a página registra um erro, e o laço de `requestAnimationFrame`
que já estava agendado segue rodando. O herói nunca saiu da tela, então minha
checagem testava justamente a única coisa que a regressão não quebra.

A afirmação que pega a regressão conta os erros da página antes e depois do
ESC. "O herói ainda anda depois do ESC" ficou como segunda linha de defesa, para
o caso de o build mudar um dia para `EXIT_RUNTIME=1`.

Isso virou a regra da bancada inteira: toda afirmação tinha que ser vista
falhando. Coloca o bug de volta, vê a checagem ficar vermelha, desfaz. No caso
do `GL_POLYGON`, isso significou editar o patch de volta para
`glBegin(GL_POLYGON)`, recompilar e ver a bancada pegar o abort. Uma checagem
nem sobreviveu à regra: "segurar W pula mais alto que tocar" comparava contra o
`Math.min` de uma lista que podia vir vazia. `Math.min()` de nada é `Infinity`,
então qualquer altura passava.

## O que o jogo fez com a página

Alguns bugs iam no sentido contrário: era o jogo quebrando a página em volta
dele.

O GLUT do Emscripten escuta `keydown` e `keyup` na janela inteira e chama
`preventDefault` em Tab, Enter e Espaço. O jogo não usa nenhuma das três.
Depois que alguém clicava em Jogar, quem navega por teclado ficava preso no
canvas: o Tab não chegava ao rodapé, nem ao botão de tema, nem ao "jogar de
novo" da tela de fim do próprio jogo. A correção é um listener em captura na
janela, registrado antes de o módulo do jogo carregar, que segura essas três
teclas antes de o GLUT ver.

A tela de fim tinha um bug próprio. As fontes bitmap do GLUT não existem no
Emscripten, então "Você venceu" e "Você perdeu" agora são HTML por cima do
canvas. O C++ chama a página a cada quadro enquanto o jogo está acabado. Quando
o R reinicia, ele simplesmente para de chamar, e nada avisava a página para
esconder a mensagem. O overlay ficava por cima de um jogo rodando e engolia
todos os cliques. Agora o `restartGame()` avisa a página quando o jogo volta.

O último só apareceu no site de verdade. A bancada servia os três arquivos do
build de um diretório só. No site, a página mora em `/projects/...` e o jogo em
`/demos/...`. O loader do Emscripten procura o `jogo.data` (a arena SVG
empacotada) relativo à página, não ao `jogo.js`, então no site real era 404
toda vez. Uma opção `locateFile` no loader resolveu, e a bancada ganhou um
segundo modo que carrega a página construída de verdade, porque a versão de
diretório único não tem como ver esse tipo de bug.

## Três patches, e muita bancada

O jogo em si quase não mudou. São três patches pequenos, aplicados sobre um
commit fixo do repositório original, e o próprio `make` do trabalho ainda gera
a versão de desktop com o texto original do GLUT. Quase todo o trabalho foi
provar que a versão do navegador roda de verdade.

Entrei achando que a parte difícil seria o OpenGL. A maior parte do tempo foi
em testes que passavam quando não deviam. Hoje eu não confio numa checagem até
ver ela falhar.
