---
layout: project
title: Jogo da Velha em Assembly x86
locale: pt
slug: tic-tac-toe
year: 2019
featured: true
order: 1
summary: Um jogo da velha escrito em assembly x86 de 16 bits para DOS, que desenha o próprio tabuleiro em modo gráfico VGA.
tech: [Assembly x86, NASM, DOS, VGA]
repo: https://github.com/viniciuscole/tic-tac-toe-assembly
demo:
  type: none
---

O jogo inteiro é escrito em assembly NASM de 16 bits em modo real, para DOS. Ele
troca o vídeo para o modo VGA 12h (640x480, 16 cores) via `int 10h` e desenha
cada linha e círculo por conta própria: `draw.asm` implementa os algoritmos de
Bresenham para linha e círculo e o traçado de pixel, enquanto `vca.asm` concentra
a lógica do jogo, o interpretador de comandos e a detecção de vitória.

As jogadas são digitadas como comandos. `X11` joga X na linha 1, coluna 1; `c`
começa uma partida nova; `s` sai e restaura o modo de vídeo anterior.
