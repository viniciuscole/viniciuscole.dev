---
layout: post
title: "Linking is not running: a C++ OpenGL game in the browser"
locale: en
slug: linking-is-not-running
date: 2026-11-01
tags: [webassembly, opengl, testing]
---

The [side-scrolling game](/projects/2d-graphics/) on this site was a
Computer Graphics assignment: C++, immediate-mode OpenGL, GLUT, an arena read
from an SVG file. Porting it was the opposite of the
[tic-tac-toe port](/2026/08/16/porting-dos-assembly-to-the-browser/). There, a
1.4 MB emulator runs a 3 KB DOS program. Here there is no emulator. The
181,051 bytes of `jogo.wasm` are my C++, compiled by Emscripten.

Getting it to compile took one command:

```
em++ -std=c++11 -O2 main.cpp arena.cpp tinyxml2.cpp character.cpp \
     hero.cpp enemy.cpp shot.cpp \
     -sLEGACY_GL_EMULATION=1 -lGL -lglut \
     --preload-file arena_teste.svg -o jogo.js
```

It linked clean. I almost wrote down "immediate-mode OpenGL works". Then I opened
it in a browser, and it died on the first frame:

```
Aborted(unsupported immediate mode 9)
```

Mode 9 is `GL_POLYGON`, which the game uses to draw every character's head.
Emscripten's emulation of old-style OpenGL doesn't implement it. The fix is
one word, `GL_TRIANGLE_FAN`, which draws the same thing for a convex shape.

The fix was easy. What stuck with me is that no check short of running the
program could have caught the bug. The compiler accepted it. The linker accepted
it. The output files existed and had plausible sizes. Every check I could run
without a browser passed on a program that couldn't draw a single frame.

So I built a bench: a script that opens the game in a real Chromium (headless,
inside the Playwright Docker image), presses keys and clicks the mouse, and
checks what happens on screen. Most of what I learned from this port came from
that bench being wrong.

## You can't read a WebGL canvas

The first thing the bench needs is "did anything draw?". The obvious answer is
to read the canvas pixels. That returns solid black, every time, because WebGL
throws the drawing buffer away once the frame is on screen unless you ask it
not to.

What works is going the long way round. Take a Playwright screenshot, load it
into an `<img>`, draw that onto a 2D canvas and call `getImageData`. Every
measurement in the bench goes through that path.

## A test that passes with the keyboard unplugged

The first version of "pressing D moves the player" compared two screenshots of
the whole canvas, one before the key and one after, and passed if they were
different.

They are always different. The arena has seven enemies that walk and shoot on
their own from the first frame. The picture changes between any two moments,
with or without a keyboard. The test would have passed with input completely
broken, which is worse than not having it, since everything after it trusted it.

The fix was to measure the thing that should move. The hero is the only green
on screen, so the bench finds the horizontal centre of the green pixels and
asserts that D pushes it more than 20 px right and A pulls it back. It has to be
measured near the spawn point, too: the camera follows the hero, so after a few
steps the hero stays centred and the on-screen movement shrinks to almost
nothing.

The jump had its own timing trap. A quick tap of W lifts the hero 21 px and lands
in under 90 ms. My first measurement ran 250 ms after releasing the key, saw the
hero on the ground and reported a failure that wasn't one. Holding W for 900 ms
reaches 147 px. The bench now takes three samples right after release and keeps
the highest point.

## `exit(0)` doesn't exit

The original game quits on ESC with `exit(0)`. On a desktop that's fine. On a
web page there is nowhere to quit to, so the port turns ESC into a no-op. The
bench checked that by pressing ESC and confirming the hero was still visible.

That check was useless, and I only found out by breaking the guard on purpose
and rebuilding. With Emscripten's `-sEXIT_RUNTIME=0`, `exit(0)` doesn't stop
anything. It throws an uncaught `ExitStatus` exception inside the key handler,
the page logs an error, and the `requestAnimationFrame` loop that was already
scheduled keeps going. The hero never left the screen, so my check was
testing the one thing the regression doesn't break.

The assertion that catches the regression counts page errors before and after
ESC. "The hero can still walk after ESC" stays in as a second line of defence,
in case the build ever switches to `EXIT_RUNTIME=1`.

This became the rule for the whole bench. Every assertion had to be shown to
fail: put the bug back, watch the check go red, then restore it. For the
`GL_POLYGON` fix that meant editing the patch back to `glBegin(GL_POLYGON)`,
rebuilding, and seeing the bench catch the abort. One check didn't survive
the rule at all: "holding W jumps higher than tapping" compared against
`Math.min` of a list that could be empty. `Math.min()` of nothing is
`Infinity`, so any height passed.

## What the game did to the page

Some bugs went the other way: the game broke the page around it.

GLUT on Emscripten listens to `keydown` and `keyup` on the whole window and
calls `preventDefault` on Tab, Enter and Space. The game doesn't use any of
them. Once someone clicked Play, keyboard users were stuck on the canvas. Tab
couldn't reach the footer or the theme button, or even the "play again"
button on the game's own end screen. The fix is a capturing listener on the
window, registered before the game module loads, that stops those three keys
before GLUT sees them.

The end screen had a bug of its own. GLUT's bitmap fonts don't exist in
Emscripten, so "You won" and "You lost" are HTML now, shown over the canvas. The
C++ calls into the page on every frame while the game is over. When R restarts
the game it just stops calling, and nothing told the page to hide the message.
The overlay stayed on top of a running game and swallowed every click. Now
`restartGame()` tells the page when play starts again.

The last one only showed up on the real site. The bench served the three build
files from one flat directory. On the site, the page lives at `/projects/...`
and the game at `/demos/...`. Emscripten's loader looks for `jogo.data` (the
packed SVG arena) relative to the page, not to `jogo.js`, so on the real site it
was a 404 every time. A `locateFile` option in the loader fixed it, and the
bench gained a second mode that loads the real built page, because the flat
version can't see this kind of bug by design.

## Three patches, and a lot of bench

The game itself barely changed. Three small patches, applied to a pinned commit
of the original repo, and the assignment's own `make` still builds the desktop
version with the original GLUT text. Almost all of the work was in proving that
the browser build actually runs.

I went in thinking the hard part would be OpenGL. Most of the time went into
tests that passed when they shouldn't have. Now I don't trust a check until
I've watched it fail.
