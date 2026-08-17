---
layout: post
title: Porting DOS assembly to the browser
locale: en
date: 2026-08-16
---

My tic-tac-toe game is written in 16-bit x86 real mode assembly. There is no
compiler that turns that into WebAssembly — the instruction set, the segmented
memory model and the DOS interrupts have no equivalent target.

So the plan is emulation: assemble the original source with NASM, link it into a
DOS executable, and run that executable inside DOSBox compiled to WebAssembly.
The WebAssembly here is the emulator, not my code, and I think that honesty
matters more than the label.

The build already works: `nasm -f obj` assembles both source files without a
single change, and Open Watcom's linker produces a 3,244 byte DOS executable.
