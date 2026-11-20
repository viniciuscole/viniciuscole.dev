---
layout: post
title: Frame-accurate seeking with WebCodecs
locale: en
slug: frame-accurate-seeking
date: 2026-11-20 00:00:30 -03:00
tags: [video, webcodecs, testing]
---

An editor has to show the exact frame under the playhead. If you cut on frame
118, frame 118 is what the preview shows, not something close to it. The
[editor](https://viniciuscole.com/lab/editor/) does this with WebCodecs, and
WebCodecs gives you very little: a `VideoDecoder` that takes encoded chunks
and hands back `VideoFrame`s. Finding the right chunks, deciding which frames
to keep and when to throw them away is up to you. This is the part of the
[architecture](/2026/11/20/how-it-works/) that the spec calls the core of
the project.

## The recipe

A video is a series of keyframes, each followed by frames that only make sense
relative to the ones before them. To show frame `n`, the render worker looks
up the previous keyframe in an index built at import, resets the decoder,
feeds it from that keyframe forward and drops every frame before the target.
If the target is later in the group of pictures (GOP) the decoder is already
in, it keeps going without a reset, so stepping forward one frame is cheap.

The test clips make this checkable. Each frame has its number burned in, a
background colour that changes every second and an 8-bit strip that encodes
the frame number. The tests seek and then read the strip back from the
preview's pixels. One clip runs at 29.97 fps with a single keyframe, so frame
149 is 149 frames away from its keyframe.

An early review caught that frame 0's strip is all black, so a blank canvas
also reads as frame 0. Now the reader returns nothing unless the background
is one of the clip's known colours.

## Frame 0 doesn't start at zero

The first version numbered frames by their absolute timestamp. The reviewer
remuxed a test clip with every packet shifted by 0.1 s and imported it:

```
UndecodableMediaError: moved.webm couldn't be decoded: No decodable frame at frame 0
```

The first frame was at 100 ms, so it landed at index 3 and index 0 never
existed. That isn't an exotic file. An MP4 with B-frames muxed without an edit
list starts a couple of frames in, and so do remuxes from MPEG-TS. The fix
anchors the frame grid at the track's first presentation timestamp, recorded
at import. Shifted clips joined the test fixtures, in both encodings.

## Seeks that arrive too late

Seeks can arrive faster than the decoder can finish them. Every request carries a generation number, and the worker stops a decode
as soon as a newer one arrives.

The second review round found the one place that wasn't checked: right after
the flush at the end of a GOP, which is where every seek to the last frames of
a clip goes. The reviewer added a temporary throw for "a frame came back after
a newer seek arrived" and ran a sweep: seek to the last frame, wait 0 to
40 ms, seek to frame 3. It fired on three of the four test clips:

```
STALE_DRAW frame 119 gen 2 latest 3
STALE_DRAW frame 149 gen 2 latest 3
```

The preview flashed the old frame before the right one. The existing test
couldn't see it, because the stale frame was drawn first and the order of
frames still looked right. There are now two checks, one after the flush and
one at draw time, and a counter of frames drawn after a newer seek had
arrived. The test asserts it stays at 0. With both checks removed, it fails on
all four clips.

## Frames belong to the decoder

A `VideoFrame` is a handle to memory the decoder owns. Keep too many of them
and a hardware decoder runs out of output buffers and stops producing frames,
with no error. So the cache is an LRU with a byte budget, and every frame it
evicts is closed explicitly.

The budget is 96 MB, shared by every clip. At 1080p that's around 30 frames.
At 4K it's about 8. During playback, frames behind the playhead are evicted
first, then the frame farthest ahead.

A wait for the decoder can still hang, so it has a 2-second stall timer. The
first version started the timer once per flush, and a healthy flush that took
more than 2 seconds on a slow machine counted as a stall. The recovery then
cleared the cache, which could close the target frame, and fell back to the
next frame it had. The wrong frame on screen, no error. Now the timer restarts
on every frame that comes out, and after a stall the target is decoded again
from its keyframe or the request fails. It never shows a different frame.

Leaks are counted too. The worker tracks every frame from the moment a decoder
outputs it until it's closed. After one merge, CI on `main` failed with
`expected 83 to be 82`: one frame alive outside the cache after a pause. The
decoder keeps emitting frames for packets already queued, after the task that
asked for them has gone. The last of those landed in a slot meant for
fallbacks, and nothing was left to close it. Now a frame like that is closed
on arrival unless some task can still use it.

## One decoder per clip, four in total

Hardware decoders are scarce, so the pool has a hard limit of 4. Each clip
that is being read gets its own decoder, since two clips of the same file need
two positions in it. When the limit is hit, the least recently used idle
decoder is reset and handed over.

Scrubbing, dragging the playhead, uses a cheaper mode. While you drag, the
preview shows the nearest keyframe and a small `KEYFRAME` chip. When you let
go, it seeks to the exact frame. The keyframe is decoded on the clip's own
decoder, so a drag never opens a second one. The first version did open a
second decoder for that, and the review sent it back.

That reuse needed two more lines: after decoding a lone keyframe, the clip
has to forget where its decoder was in the GOP. The reviewer deleted them and
all 115 tests still passed. Then it wrote a seek, scrub and release sequence
and got 12 failures out of 16. The test that now covers it fails with the
decoder's own error:

```
DataError: ... A key frame is required after configure() or flush()
```

## While an export runs

Export renders in its own workers and needs decoders too. When it starts, the
preview drops to one decoder and shows only keyframes, and the export lanes
share the other three, so the total never goes above 4. The
[export post](/2026/11/20/export/) covers the rest.

Most of these bugs surfaced because a reviewer went looking for the bad
timing: a shifted clip, a second seek 7 ms after the first, a scrub right
after a seek inside a GOP. The seek and scrub PRs each took three review
rounds.
