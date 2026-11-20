---
layout: post
title: Syncing video to the audio clock across threads
locale: en
slug: audio-clock
date: 2026-11-20
tags: [video, audio, testing]
---

When video and audio disagree during playback, one of them has to give way.
In the [editor](https://viniciuscole.com/lab/editor/) it's always the video.
A dropped frame is hard to notice. A gap or a click in the audio isn't. So the
`AudioContext` is the master clock, and the picture follows it.

That would be simple if both lived in the same place. They don't. The
`AudioContext` only exists on the main thread, and the video frames are
decoded and drawn in a render worker (the
[overview](/2026/11/20/how-it-works/) explains why). This post is about
keeping two threads in step, and about audio that has to sound the same in
the preview and in the [exported file](/2026/11/20/export/).

## Audio without streaming

Each asset's audio is decoded once with `decodeAudioData` and kept in memory
as an `AudioBuffer`. Playback schedules one `AudioBufferSourceNode` per
audible clip, through a gain node for the clip and another for the track. On
a seek or an edit during playback, the scheduled nodes are stopped and
scheduled again from the current time.

It costs memory: the spec estimates about 230 MB for ten minutes of 48 kHz
stereo. The alternative, decoding in chunks with `AudioDecoder` and feeding
an `AudioWorklet` through ring buffers, is in the spec's out-of-scope list.
Nothing in the editor shares memory between threads, so there is no
`SharedArrayBuffer`. The editor needs no cross-origin isolation headers
(COOP and COEP), and the deploy sets none.

## Anchors

The main thread doesn't stream the clock to the worker. It sends anchors: on
play, on every seek and every 250 ms it posts `{ timeUs, wallMs, rate }`,
meaning "at this moment on the page's clock, the timeline is at this time and
moving at this rate". The worker extrapolates between anchors and draws the
frame that matches.

The audio time comes from `AudioContext.getOutputTimestamp()`. It pairs the
context time of the sample that is leaving the speakers now with the matching
`performance.now()`, so output latency is already accounted for. Before a
timestamp is available it falls back to
`currentTime − outputLatency − baseLatency`.

Two things were added in testing. The audio device sometimes started later
than predicted, so the main thread also checks every 20 ms and posts a new
anchor when the audio clock has moved more than 4 ms away from the last one.
And an anchor can be dated in the future: "the timeline starts moving at
`wallMs`". The worker holds the first frame until the first sample can be
heard, instead of running ahead of it.

## Whose `now`?

An anchor has a time on the page's clock, and the worker has to turn it into
its own. `performance.now()` in a worker counts from a different origin than
on the page.

The first version estimated the offset as the smallest message delay it had
seen. While the worker was busy decoding, that estimate started tens of
milliseconds too high, and for the first few seconds the video lagged the
clock by about a frame. The next idea was `performance.timeOrigin`. Chrome
derives it from the wall clock, and on WSL a worker created later in the
page's life came out about 2 seconds off.

What works is to measure. The worker answers a `now` request right away,
outside its queue of work. The editor takes five samples when it opens and
one more on every play, and keeps the one with the shortest round trip.

## Measuring the drift

The tests need a number for "in sync". Every time the worker draws a frame
during playback, it records the draw time. The main thread then asks the
audio clock which frame was playing at that instant, and stores the
difference. The tests assert that the largest difference over a play-through
stays at one frame or less, and that at least 80% of the frames were checked.

The reviewer pointed out a limit of that measurement. The draw time is
converted back to page time with the same offset the worker used, so an error
in the offset cancels itself out and can't show up. The error is at most half
of the best round trip, below a millisecond when the worker is idle. It's
written down as a follow-up rather than hidden.

In tests, Chrome starts with `--autoplay-policy=no-user-gesture-required`, so
the real `AudioContext` runs and the tests go through the production audio
path. In the app, the context starts suspended and the first Play resumes it.

## Play, pause, play

That `resume()` gave the two bugs I like most in this part.

The first: in the app, `resume()` can take up to 500 ms. Press Play, Pause,
Play before it finishes, and the first play's audio still starts when it
finishes. Each play had its own audio clock, and the first one scheduled its
voice after it had already been stopped. Two copies of the audio played, out
of step, and Pause only stopped one. A double tap on the space bar was
enough. The test stubs a slow `resume()` and counts the voices.

The fix for that made a superseded play stop the clock it had started. But
without audio, all plays share one wall clock. A stale play stopped the clock
the new play was running on, and the playhead froze while the Pause button
showed. The reviewer caught it with the same Play, Pause, Play sequence on a
clip without sound, and the test written for it fails on the old code with:

```
expected 0 to be greater than 15
```

Now a play only stops a shared clock when no newer play is using it. The
first round of fixes had also given every stop a 5 ms fade, because cutting a
sound mid-wave clicks.

## Many tracks, one plan

Several audio tracks came later: mute per track, volume per clip (0 to 200%)
and fades in and out. The fade is linear in gain:
`volume × min(1, (t − start) / fadeIn, (end − t) / fadeOut)`. Mute ramps the
track's gain with a 2 ms time constant, so it doesn't click either.

The important decision is that none of that is a live change to the playback
graph. Volume, fades and mute are fields of a plan (one entry per voice, with
the track gain and the gain curve), and the same function schedules that plan
for playback, for the offline render the tests read samples from, and for the
10-second chunks of the export. When a mix starts in the middle of a fade,
as it can at an export chunk boundary, the curve is cut at the voice's
start so it begins at the right gain.

The reviewer tested that with eight mutations, and every one failed some
test. Mixing the second track in the preview but not in the export failed 4
tests. An equal-power fade instead of a linear one failed the curve tests. A
fade one frame too long missed the 2e-3 limit by a hair, at 2.31e-3, and a
second assertion caught it with more room.

There's no limiter. Two loud tracks, or a clip at 200%, can go over 1.0 and
clip, but they clip identically in the preview and in the file. Clips at a
speed other than 1× are silent, as the spec allows for now.

Because preview and export run the same plan, "the export sounds like the
preview" holds by construction. What the tests have to check is the plan, and
that was a much smaller thing to get right.
