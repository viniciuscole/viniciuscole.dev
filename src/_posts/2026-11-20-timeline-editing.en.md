---
layout: post
title: Timeline editing with undo and redo
locale: en
slug: timeline-editing
date: 2026-11-20
tags: [video, testing]
---

The timeline of the [editor](https://viniciuscole.com/lab/editor/) does what
you'd expect: trim, move, split, delete, ripple delete, crossfades, clip
speed, undo and redo. None of it is hard to describe. The difficulty is
keeping a few rules true after any sequence of edits, so this post is mostly
about how those rules are stated and tested. The
[overview](/2026/11/20/how-it-works/) has the rest of the architecture.

## Integers on a frame grid

Time in the document is an integer number of microseconds, and every edit
point snaps to a frame of the project. Frame `n` is at
`round(n · 1e6 · den / num)`, so at 29.97 fps (30000/1001) frame 100 is
3,336,667 µs. Integers keep that exact where floats would drift.

Converting back and forth still loses a microsecond here and there, so code
that needs to know which source frame a timeline frame shows does the
arithmetic in frame indices, not in microseconds. The first timeline PR found
1 µs rounding errors at 29.97 doing it the other way.

## Commands and patches

Every change goes through a named command, and the store is small enough to
show:

```ts
dispatch(command: Command): boolean {
  const [next, patches, inverse] = produceWithPatches(this.current, (draft) => {
    command.apply(draft);
    pruneTransitions(draft);
  });
  if (patches.length === 0) return false;
  ...
}
```

Immer's `produceWithPatches` returns the new document plus the patches in
both directions. Undo applies the inverse, redo applies the forward ones, and
every patch set also goes to the render worker, which keeps its own copy of
the document. A command that changes nothing produces no patches and no undo
step.

A drag isn't a stream of commands. While you drag, pure functions compute a
preview of where the clip would go, and the document only changes on release,
as one `moveClip` or `trimClip`. One drag, one undo step. Escape cancels it
with nothing to undo.

Ripple delete closes the gap on every track, so the tracks stay in sync. If a
clip on another track overlaps the range being removed, the ripple is refused
and a toast names the clip and the track. The shift is done in frames, so
29.97 fps clips stay on the grid.

## Rules, checked at random

The spec lists the rules: clips never overlap on a track, every edit point is
on a frame, transitions never use more footage than exists, a clip only
appears inside its own interval, and undoing everything returns the starting
document. They are checked with fast-check property tests that generate
random sequences of add, trim, move, drag, split, delete, ripple, crossfade,
speed, undo and redo, and check every rule after every step. The worker's
copy of the document has to be equal to the main thread's at every step too.

The setup of the test matters too. One reviewer noticed the test
only reset the document after a run that passed, so a failing run shrank
against a dirty document and the counterexamples couldn't be trusted. Each
run now opens a fresh editor.

## Crossfades without overlap

Clips never overlap, so a crossfade can't be two clips sliding over each
other. It sits on the cut and borrows footage the clips aren't showing: from
after the outgoing clip's out point and from before the incoming clip's in
point. Those extra frames are the handles. If there isn't enough footage, the
crossfade gets shorter and the inspector says "Shortened to X s: not enough
footage beyond the cut." The document keeps the length you asked for, so it
grows back when a trim frees up footage.

The review of that PR found the property test didn't really protect the
handle rule. Most cuts came from splits, where the clip length runs out
before the footage does. With the limit on footage before the in point
removed, the test still passed at the committed 25 runs. At 150 runs it
failed once, on run 103, with this sequence:

```
add(in 14, len 1), append(in 0, len 1), crossfade(2)
```

The generator now leans toward clips with very little footage on either side,
and both handle mutations fail it 5 times out of 5.

## Speed, and half frames

Clip speed was the ticket where the frame grid pushed back. A clip keeps its
source range, and its timeline length becomes
`max(1, round(sourceFrames / speed))`. Timeline frame `i` shows source frame
`floor(in + i · speed)`: every second frame at 2×, each frame twice at 0.5×,
and frames 0, 1, 3, 4, 6 at 1.5×.

The first version trimmed by rounding the source change on every step. Take a
clip showing source frames 20 to 50 at 0.5×, so 60 frames on the timeline. A
one-frame trim at the end moves the source by half a frame, and
`Math.round(-0.5)` in JavaScript is `-0`. The reviewer trimmed the end ten
times: the clip got 10 frames shorter and the source out point didn't move.
Trimming the start ten times moved the in point from 20 to 30 instead of 25,
because `Math.round(0.5)` is 1. After that, the last frame of the clip showed
source frame 54, past its out point at 50, and trimming back never restored
the original.

There's no way to get that right on whole frames. A one-frame trim at 0.5× has
to move the source by half a frame. So source in and out points are now stored
on a grid of 1/100 of a frame, and speeds are quantised to 0.01, so a trim
moves the source by exactly `speed` frames and repeated trims never drift. The
spec says every edit point snaps to a frame. Timeline points still do, but
source points of a clip that isn't at 1× don't, and the PR lists that as a
deviation from the spec. Setting a clip back to 1× snaps its source range
outward to whole frames.

## The counterexample

The next review round found the property test failing at random. fast-check
shrank it to this:

```
[{"inFrame":33,"length":1},0,3,[{"edge":"start","frames":0}],0]
AssertionError: source range, speed and duration disagree:
  expected 0.6666666666666667 to be less than or equal to 0.500001
```

The invariant said a clip's length is within half a frame of its footage
divided by its speed. But a clip one source frame long at 3× is one timeline
frame long, because of the `max(1, …)` floor, and |1/3 − 1| is 0.67. The code
was right and the invariant was wrong. It only failed on runs where the
random seed happened to draw a one-frame clip at 3×, and CI had been green by
luck.

Working it out properly: a trim keeps `L − S/s` constant (L timeline frames,
S source frames, speed s), and a speed change puts it between −0.5 and 0.5,
except at the one-frame floor. So the reachable range is
`−0.5 ≤ L − S/s < 1`, and the test asserts those two bounds. The upper one
says a clip never shows a frame past its out point. The lower one says it's
never more than half a frame short. The reviewer put back the original
rounding bug and the new lower bound caught it on its own.

The rounding bug was found by a reviewer trimming by hand, not by the
property test. Then the property test failed because of its own mistake. The
rule a random test checks needs the same review as the code it checks.
