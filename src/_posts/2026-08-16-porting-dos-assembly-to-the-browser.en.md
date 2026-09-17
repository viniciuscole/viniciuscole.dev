---
layout: post
title: Porting DOS assembly to the browser
locale: en
slug: porting-dos-assembly-to-the-browser
date: 2026-08-16
tags: [assembly, emulation, webassembly]
---

My tic-tac-toe game is written in 16-bit x86 real mode assembly. There is no
compiler that turns that into WebAssembly. The instruction set, the segmented
memory model and the DOS interrupts have no equivalent target.

So the plan is emulation: assemble the original source with NASM, link it into a
DOS executable, and run that executable inside DOSBox compiled to WebAssembly.
The WebAssembly here is the emulator, not my code, and I think that honesty
matters more than the label.

The build already works: `nasm -f obj` assembles both source files without a
single change, and Open Watcom's linker produces a 3,244 byte DOS executable.

## What the game actually does

It is 1,740 lines across two files. `vca.asm` holds the game: the command
parser, the board, win detection. `draw.asm` holds the graphics primitives.

The entire game state is nine bytes:

```
tabuleiro    db    '         '
```

Nine ASCII spaces. A move overwrites one of them with `X` or `C`, and a new game
is nine spaces again. There is no struct, no bitboard, no packing. The board is
literally the string you would draw on paper.

Win detection is fully unrolled. Eight winning lines, two players, sixteen
blocks of explicit `cmp byte [tabuleiro + n], al`, one after another, with no
loop and no table of line indices. That single decision accounts for a good
share of the 1,187 lines in `vca.asm`.

Everything on screen arrives by one of two routes, and the two have nothing in
common. The position labels are BIOS text: `int 10h` with `AH=02h` to place the
cursor and `AH=09h` to write a character in the ROM font, straight onto a
graphics-mode screen. The board, the crosses and the circles are pixels, plotted
one at a time by Bresenham routines the game implements itself.

## One interrupt per pixel

`draw.asm` is 553 lines and contains exactly three `int 10h` calls. The third one
is the whole graphics layer:

```
plot_xy:
        ; ... prologue: saves bp and every register it touches
        mov     ah,0ch
        mov     al,[cor]
        mov     bh,0
        mov     dx,479
        sub     dx,[bp+4]
        mov     cx,[bp+6]
        int     10h
```

`AH=0Ch` is the BIOS write-pixel service. Every line, every circle, every X on
the board goes through it, one pixel per interrupt. Nothing is ever written
directly to video memory at `A000h`, and none of the VGA planar tricks that made
mode 12h fast are anywhere in the source.

The `mov dx,479 / sub dx,[bp+4]` is the other detail I like. VGA counts rows from
the top; the game thinks bottom-left, like graph paper. Rather than convert at
every call site, it flips the axis once, inside the only routine that touches a
pixel.

The cost is easy to measure. The empty grid is two horizontal lines 313 pixels
long and two vertical lines 297 pixels long: about 1,220 BIOS calls before a
single move is played. A circle of radius 40 is another 250 or so. In the
browser every one of those traps into the emulator instead of into real ROM.

It does not matter (a tic-tac-toe board is a few thousand pixels, and the thing
draws instantly), but it does clarify what emulation is buying here. Not speed.
Fidelity of a BIOS that has not existed in hardware for decades.

## The shape of the bundle

js-dos takes a `.jsdos` file, which turns out to be a plain zip. Mine holds two
files: `VCA.EXE`, and a 77-byte `.jsdos/dosbox.conf` telling DOSBox to boot the
machine as `vgaonly`, mount the bundle as `C:` and run the executable. That is
the entire packaging step.

The whole bundle is 2,236 bytes. The emulator that runs it is 1.4 MB of
`wdosbox.wasm` plus another 315 KB of loader. The WebAssembly alone is 450 times
the size of the 3,244-byte program it exists to run. That asymmetry is why the
demo loads on a click and not on page load: someone who came to read about the
project should not pay for a DOS box they never asked to boot.

## Two things the browser half cost me

js-dos defaults `pathPrefix` to its own CDN. Leave it alone and the page quietly
downloads 1.4 MB of WebAssembly from someone else's server, which is exactly the
thing this site is built not to do. The failure is silent: everything works, and
the page just is not what I said it was. My existing check for third-party
requests read `src` and `href` attributes out of the built HTML, so it was blind
by construction: this request is born at runtime, inside JavaScript. The new
check scans the published JavaScript for off-origin URLs instead.

The second one was louder. js-dos ships a stylesheet, and that stylesheet opens
with a full Tailwind reset: `h1..h6{font-size:inherit}`, `a{color:inherit;
text-decoration:inherit}`. It loads after mine, at the same specificity. Clicking
"Play" flattened every heading and drained the colour out of every link on the
page, all at once. The fix was to stop serving those 118 KB entirely and
hand-write the handful of rules the emulator's own DOM actually needs, scoped
under `.demo-screen`.

## The readme was wrong

The game's readme says to type `OLC` to play a circle. The code compares against
`'C'`, at `vca.asm:80`, and `C22` is what worked when I first ran it under
DOSBox. The messages never moved: the game still prints `O Venceu` and
`Vez do O`. At some point the display kept `O` and the parser took `C`, and the
readme followed the half that was easier to see.

So the demo documents `C`, and there is a test that fails if anyone helpfully
"corrects" it back to `O` by reading the readme. It is a small thing, but it is
the kind of thing that only surfaces when you actually run the program instead of
describing it. Seven years later, that is most of what this port was for.
