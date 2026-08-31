---
title: Side-Scrolling Game in C++ and OpenGL
locale: en
slug: 2d-graphics
year: 2024
featured: true
order: 2
summary: A side-scrolling shooter in C++ with OpenGL and GLUT, reading its arena from an SVG file, compiled to WebAssembly to run here.
tech: [C++, OpenGL, GLUT, Emscripten, WebAssembly]
repo: https://github.com/viniciuscole/2D-Computer-Graphics
demo:
  type: wasm
  base: /demos/2d-graphics/jogo
---

The game reads its arena from an SVG file: the blue rectangle is the field,
black rectangles are obstacles, the green circle marks where the player
starts and the red ones mark the opponents (seven of them). The circles
only carry position and scale — each character is drawn from scratch around
them, with a head, a torso, an articulated arm and two legs hinged at hip
and knee, animated as they walk. The arm follows the mouse, and the left
button fires.

The arena is nine screens wide; the square window tracks the player
horizontally. The goal is to cross from left to right without being hit.

All rendering uses immediate-mode OpenGL — `glBegin`, `glVertex2f`,
`glOrtho` — and the SVG is parsed with
[tinyxml2](https://github.com/leethomason/tinyxml2) (zlib licence),
compiled in.

## What it cost to bring here

Emscripten compiles the C++ to WebAssembly, but it does not implement
everything GLUT offers. Two things had to change.

`GL_POLYGON`, used to draw the circles, does not exist in its immediate-mode
emulation: the program compiled and linked without complaint, then aborted
on the first frame. Swapped for `GL_TRIANGLE_FAN`, which draws exactly the
same thing for a convex polygon.

The end-of-game messages were drawn with GLUT bitmap fonts, which Emscripten
also lacks. They became HTML over the canvas — which, as a side effect, got
them translated.

The two changes reached the code differently. The `GL_POLYGON` swap is a
plain substitution, with no guard at all — harmless for the native build
because, as already noted, the triangle fan draws the same thing as the
polygon for a convex shape. The message swap, though, sits inside an
`#ifdef __EMSCRIPTEN__ ... #else ... #endif` block, keeping the original
GLUT drawing in the `#else` branch.

The assignment's own `make` still produces the native `trabalhocg`
executable, with the messages drawn as they always were. The port didn't
replace the original — it gained a second target, by two different
routes.

Beyond that, the game here is the one that runs natively: the roughly 180 KB
of WebAssembly on this page are the project's own C++, compiled. There is no
emulator in between.
