---
title: 3D Game in C++ and OpenGL
locale: en
slug: 3d-graphics
year: 2024
featured: true
order: 3
summary: The three-dimensional evolution of the previous game, with a flashlight, a minimap and the same SVG arena — shown here on video, because the browser's OpenGL emulation cannot carry its lighting.
tech: [C++, OpenGL, GLUT, GLU]
repo: https://github.com/viniciuscole/3D-Computer-Graphics
demo:
  type: video
  base: /demos/3d-graphics/jogo3d
---

It is the same game as the earlier project, evolved into three dimensions:
the arena is still read from an SVG file, still parsed with
[tinyxml2](https://github.com/leethomason/tinyxml2), and the same character
classes — hero, enemy and shot — are now drawn with depth.

Rendering uses immediate-mode, fixed-function OpenGL: three lights,
materials, textures and depth testing. One of the lights is a flashlight
attached to the player's arm — there is a mode where the ambient lights
switch off and only it lights the scene. Characters are built from spheres
(GLU quadrics) and prisms; a minimap marks the player's position inside the
arena.

## Why this page only has a video

Emscripten's fixed-function OpenGL emulation does not implement
`GL_SPOT_CUTOFF`, `GL_SPOT_EXPONENT` or `GL_SPOT_DIRECTION` — the
parameters that turn a positional light into a cone, which is exactly what
the flashlight mode needs. The game compiles and links without complaint;
the screen goes black the moment the flashlight enters the scene, even with
it switched off at other points in the game.

The investigation turned up two more things worth mentioning, because they
are honest and a little absurd: the textures were 30 MB of uncompressed BMP
(2000×2000 and 3000×2000 pixels, for a 500×500 window), and they load
before an OpenGL context exists — native drivers tolerate that, the browser
does not.

Rewriting the drawing code for shaders would fix the flashlight, but it
would undercut the point of the other demos on this site: that what runs
there is the assignment's own code, compiled, not a rewrite built to fit
the browser. So on this project, you watch instead of play.
