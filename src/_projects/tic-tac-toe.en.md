---
layout: project
title: Tic-Tac-Toe in x86 Assembly
locale: en
slug: tic-tac-toe
year: 2019
featured: true
order: 1
summary: A tic-tac-toe game written in 16-bit x86 assembly for DOS, drawing its own board in VGA graphics mode.
tech: [x86 Assembly, NASM, DOS, VGA]
repo: https://github.com/viniciuscole/tic-tac-toe-assembly
demo:
  type: none
---

The whole game is written in NASM 16-bit real mode assembly, targeting DOS. It
switches the display into VGA mode 12h (640x480, 16 colours) through `int 10h`
and draws every line and circle itself: `draw.asm` implements Bresenham's line
and circle algorithms plus pixel plotting, and `vca.asm` holds the game logic,
the command parser and win detection.

Moves are typed as commands. `X11` plays X on row 1, column 1; `c` starts a new
game; `s` quits and restores the previous video mode.
