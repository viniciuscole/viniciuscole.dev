---
layout: post
title: Portando assembly de DOS para o navegador
locale: pt
slug: porting-dos-assembly-to-the-browser
date: 2026-08-16
tags: [assembly, emulation, webassembly]
---

Meu jogo da velha é escrito em assembly x86 de 16 bits, em modo real. Não existe
compilador que transforme isso em WebAssembly. O conjunto de instruções, o
modelo de memória segmentada e as interrupções do DOS não têm alvo equivalente.

Então o plano é emulação: montar o código original com o NASM, linkar num
executável DOS e rodar esse executável dentro do DOSBox compilado para
WebAssembly. O WebAssembly aqui é o emulador, não o meu código, e eu acho que
essa honestidade importa mais do que o rótulo.

O build já funciona: o `nasm -f obj` monta os dois arquivos-fonte sem uma única
mudança, e o linker do Open Watcom produz um executável DOS de 3.244 bytes.

## O que o jogo realmente faz

São 1.740 linhas em dois arquivos. O `vca.asm` guarda o jogo: o interpretador de
comandos, o tabuleiro, a detecção de vitória. O `draw.asm` guarda as primitivas
gráficas.

O estado inteiro do jogo são nove bytes:

```
tabuleiro    db    '         '
```

Nove espaços ASCII. Uma jogada sobrescreve um deles com `X` ou `C`, e uma partida
nova são nove espaços de novo. Não tem struct, não tem bitboard, não tem
empacotamento. O tabuleiro é literalmente a string que você desenharia no papel.

A detecção de vitória é toda desenrolada. Oito linhas vencedoras, dois jogadores,
dezesseis blocos de `cmp byte [tabuleiro + n], al` escritos um atrás do outro,
sem laço e sem tabela de índices. Essa decisão sozinha responde por boa parte das
1.187 linhas do `vca.asm`.

Tudo que aparece na tela chega por um de dois caminhos, e os dois não têm nada em
comum. Os rótulos de posição são texto da BIOS: `int 10h` com `AH=02h` para
posicionar o cursor e `AH=09h` para escrever um caractere na fonte da ROM, direto
sobre uma tela em modo gráfico. O tabuleiro, os xis e os círculos são pixels,
traçados um a um pelas rotinas de Bresenham que o próprio jogo implementa.

## Uma interrupção por pixel

O `draw.asm` tem 553 linhas e exatamente três chamadas `int 10h`. A terceira é a
camada gráfica inteira:

```
plot_xy:
        ; ... prologo: salva o bp e todos os registradores que ele toca
        mov     ah,0ch
        mov     al,[cor]
        mov     bh,0
        mov     dx,479
        sub     dx,[bp+4]
        mov     cx,[bp+6]
        int     10h
```

`AH=0Ch` é o serviço de escrever pixel da BIOS. Toda linha, todo círculo, todo X
do tabuleiro passa por ele, um pixel por interrupção. Nada é escrito direto na
memória de vídeo em `A000h`, e nenhum dos truques de planos da VGA que faziam o
modo 12h ser rápido aparece no fonte.

O `mov dx,479 / sub dx,[bp+4]` é o outro detalhe de que eu gosto. A VGA conta as
linhas de cima para baixo; o jogo pensa a partir do canto inferior esquerdo, como
papel quadriculado. Em vez de converter em cada ponto de chamada, ele inverte o
eixo uma vez só, dentro da única rotina que toca num pixel.

O custo é fácil de medir. A grade vazia são duas linhas horizontais de 313 pixels
e duas verticais de 297: cerca de 1.220 chamadas à BIOS antes de qualquer jogada.
Um círculo de raio 40 são mais uns 250. No navegador, cada uma dessas
interrupções cai dentro do emulador em vez de cair numa ROM de verdade.

Não faz diferença (um tabuleiro de jogo da velha são alguns milhares de pixels,
e a coisa desenha na hora), mas deixa claro o que a emulação está comprando aqui.
Não é velocidade. É a fidelidade de uma BIOS que não existe em hardware há
décadas.

## O formato do bundle

O js-dos recebe um arquivo `.jsdos`, que no fim das contas é um zip comum. O meu
tem dois arquivos: o `VCA.EXE` e um `.jsdos/dosbox.conf` de 77 bytes que manda o
DOSBox subir a máquina como `vgaonly`, montar o bundle como `C:` e rodar o
executável. É esse o passo de empacotamento inteiro.

O bundle inteiro tem 2.236 bytes. O emulador que roda ele são 1,4 MB de
`wdosbox.wasm` mais 315 KB de carregador. Só o WebAssembly é 450 vezes o tamanho
do programa de 3.244 bytes que ele existe para rodar. É por causa dessa
assimetria que a demo carrega sob clique e não junto com a página: quem veio ler
sobre o projeto não deveria pagar por um DOS que nunca pediu para ligar.

## Duas coisas que a metade do navegador me custou

O js-dos usa a CDN dele como padrão do `pathPrefix`. Deixe como está e a página
baixa 1,4 MB de WebAssembly do servidor de um terceiro, que é exatamente o que
este site foi feito para não fazer. A falha é silenciosa: tudo funciona, e a
página só não é o que eu disse que ela era. A minha verificação de requisições a
terceiros lia atributos `src` e `href` do HTML gerado, então ela era cega por
construção: essa requisição nasce em tempo de execução, dentro do JavaScript. A
verificação nova varre o JavaScript publicado atrás de URLs fora da nossa origem.

A segunda foi mais barulhenta. O js-dos traz uma folha de estilo, e essa folha
abre com um reset completo do Tailwind: `h1..h6{font-size:inherit}`,
`a{color:inherit;text-decoration:inherit}`. Ela carrega depois da minha, com a
mesma especificidade. Clicar em Jogar achatava todos os títulos e apagava a cor
de todos os links da página de uma vez só. A correção foi parar de servir aqueles
118 KB e escrever à mão as poucas regras de que o DOM do emulador realmente
precisa, escopadas sob `.demo-screen`.

## O readme estava errado

O readme do jogo manda digitar `OLC` para jogar o círculo. O código compara com
`'C'`, no `vca.asm:80`, e foi `C22` que funcionou quando rodei o jogo pela
primeira vez no DOSBox. As mensagens nunca mudaram: o jogo ainda escreve
`O Venceu` e `Vez do O`. Em algum momento a tela ficou com o `O` e o parser ficou
com o `C`, e o readme seguiu a metade que era mais fácil de ver.

Então a demo documenta `C`, e existe um teste que falha se alguém "corrigir" isso
de volta para `O` lendo o readme. É uma coisa pequena, mas é o tipo de coisa que
só aparece quando se roda o programa em vez de descrever ele. Sete anos depois,
é para isso que esse porte serviu.
