---
layout: post
title: How the browser video editor works
locale: en
slug: how-it-works
date: 2026-11-20
tags: [video, webcodecs, agents]
---

The [video editor](https://viniciuscole.com/lab/editor/) on this site is a
multi-track, non-destructive editor that runs entirely in the browser. You
import clips, cut and trim them on a timeline, stack tracks, add text and
crossfades, and export an MP4. Nothing is uploaded. Your files are copied into
the browser's private storage (OPFS) and stay on your machine.

This post is the map. Four more go deeper into the parts that were hard:

- [Frame-accurate seeking with WebCodecs](/2026/11/20/frame-accurate-seeking/)
- [Timeline editing with undo and redo](/2026/11/20/timeline-editing/)
- [Exporting video in the browser with no server](/2026/11/20/export/)
- [Syncing video to the audio clock across threads](/2026/11/20/audio-clock/)

## Three threads

The main thread runs the UI, holds the project document and owns the audio
graph, because `AudioContext` doesn't exist in workers. It never touches a
video frame.

A render worker owns everything visual: the decoders, the frame cache, the
code that finds which clip is under the playhead, and the compositor that
draws into an `OffscreenCanvas`. Export spawns its own workers and reuses the
same resolver and compositor, stepping frame by frame instead of following a
clock.

Mediabunny reads and writes the containers: it demuxes MP4 and WebM, probes
the metadata, builds the keyframe index and muxes the export. Everything after
that, the decoding, the seeking and the frame cache, is written by hand on top
of WebCodecs. The spec calls that the core of the project, so it doesn't come
from a library.

## Time is an integer

Every time in the document is an integer number of microseconds, the unit
WebCodecs timestamps use. Every edit point snaps to a frame of the project,
and frame `n` lives at `round(n · 1e6 · den / num)`. At 29.97 fps (30000/1001)
frame 1 is 33,367 µs and frame 30 is exactly 1,001,000 µs. Playback, seeking
and export walk frame indices and never add up microseconds, so nothing
drifts.

## Edits are patches

Every change to the project is a named command. Immer produces a forward and
an inverse patch for each one, undo and redo replay them, and the same patches
are posted to the render worker, which keeps its own copy of the document. The
full project is never sent again after an edit. The property tests check that
the worker's copy and the main thread's copy stay equal after every random
step.

## One door for the tests

The whole editor sits behind a headless `Editor` class. The UI is a thin
client of it, and it is the only thing the tests are allowed to touch. They
import files, dispatch commands, seek and play, and then assert on what comes
out: the document, the pixels of a rendered frame, audio samples, the bytes of
an exported MP4. No test reaches into the decoder pool, the cache or the
compositor, so those can change without touching a test.

Pixels only work as an assertion if you know what they should be. The test
clips have a frame counter burned into every frame, a background colour that
changes every second, and an 8-bit strip that encodes the frame number. A
helper reads the strip back from a screenshot. Each clip exists in H.264/AAC
and in VP9/Opus, and the tests run in the branded Google Chrome, because
Playwright's bundled Chromium ships without H.264 or AAC.

## Canvas2D first, then WebGPU

The compositor is one interface with two implementations. Canvas2D came first
and covers everything: layers, picture-in-picture, opacity, text, crossfades.
The WebGPU one arrived last and has to produce the same frames. The tests
compare its output with Canvas2D's golden frames.

Video frames go into WebGPU with `importExternalTexture`, without a copy. The
result is then copied onto a 2D canvas once per frame, so the path isn't
zero-copy end to end. That copy keeps pixel readback and the fallback to
Canvas2D working on one target. In `auto` mode the editor refuses a software
WebGPU adapter, because a software WebGPU is slower than Canvas2D.

Device loss was the interesting part. Between the moment a GPU device dies and
the moment `device.lost` resolves, a draw returns a black frame and throws
nothing. In the preview that is one bad frame. In an export, running faster
than real time, it is several black frames written into the file. Now each
export lane checks that the device survived the frame and redraws it on
Canvas2D if it didn't. With that check removed, the test fails with
`exported frame 13 is black`.

CI has no GPU, so the WebGPU tests run on SwiftShader, a software
implementation. The first working setup used about 110 seconds of a
120-second timeout, roughly 6× slower than locally, and the reviewer refused
it until the timeouts had room. The first effect, a colour grade written in
WGSL, is in review as I write this. On Canvas2D, clips render without their
effects and the export panel says so.

## Who wrote it

Most of the code was written by AI agents, and how they were organised
explains a lot of what's above.

The spec is one GitHub issue. It was split into 24 tickets, linked by
"blocked by" dependencies. An orchestrator agent finds the tickets whose
blockers are closed, at most three at a time, and starts an implementer agent
for each one in its own git worktree. The implementer works test-first through
the `Editor` class, opens a draft PR and attaches evidence: test results
mapped to each acceptance criterion and, when something visible changed,
annotated screenshots and a video. Then a separate reviewer agent, which can't
edit the code, reviews the PR. After two rounds of fixes, a ticket that still
has problems comes to me. I'm the only one who merges.

Reviews are posted from my own account, so GitHub refuses "approve" and
"request changes" on them. The verdict goes in the first line of the comment.

The rule that made the reviews useful is in the reviewer's instructions: a
test that would pass with the feature removed is a finding. So the reviewer
breaks the code on purpose, runs the suite and reports what survived. Of the
23 PRs that closed a ticket, 22 came back with changes requested in the first
round.

The very first PR had one of those. Its test for "the first frame appears in
the preview" read the pixels back from the compositor's own internal canvas.
The reviewer pointed out that it would still pass if the call that hands the
visible canvas to the worker did nothing. A user would have seen an empty
preview, with the suite green. The fix was to screenshot the element the user actually sees, and later
preview tests copied that pattern.

The crossfade PR had a quieter one. A crossfade uses footage beyond the cut,
from after the outgoing clip's out point and from before the incoming clip's
in point. The reviewer replaced those handle frames with frozen copies of the
last and first frames, and all 21 crossfade tests still passed: in the test
clip, the handle frames happened to be the same colour as the frozen ones.

Not everything is solved. A few tests measure real-time playback at 4K, and
they fail when the machine is busy. They are marked as known flakes in the
PRs, not fixed.

If I had to keep one rule from all of this, it's the reviewer's: a test that
still passes with the feature removed is a bug in the test.
