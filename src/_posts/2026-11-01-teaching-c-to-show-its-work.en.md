---
layout: post
title: "Teaching a C program to show its work"
locale: en
slug: teaching-c-to-show-its-work
date: 2026-11-01
tags: [c, webassembly, algorithms]
---

The [route project](/projects/car-routes/) started as a 2023 assignment I did
with two classmates: read a map, find the fastest route, and replan when
traffic changes mid-trip. It's plain C. You give it a file, and it writes back
three lines: the path, the kilometres and the time.

That's a fine answer for a grader and a useless one for a web page. I wanted
readers to watch Dijkstra open and close nodes, see the car leave, see a road
jam and the car change its mind. The C knew all of that while it ran. It just
never said any of it out loud.

Rewriting the algorithm in JavaScript would have turned the C into a link to
the repo, and pre-recorded animations would have meant nobody could cause
their own traffic jam. So the C had to learn to narrate.

## Hooks that cost nothing when nobody listens

The C got a struct of function pointers, one per event, all `NULL` by default:

```c
typedef struct {
  void (*pop)(int node, double time);
  void (*relax)(int from, int to, double new_time);
  void (*plan)(const int *path, int length, double eta);
  void (*move)(int from, int to, double t0, double t1);
  /* ...update, replan, unreachable, done */
} TraceHooks;
```

`dijkstra` and the replanning loop call each one only if it's set. The
original command-line program never sets them, so for it the change is a
handful of `NULL` checks.

Before moving a single line, I saved the CLI's output for a few test maps as
the expected result. Any change after that had to reproduce those files
exactly. On the first run of that baseline, one of them came out like this:

```
1;2;4;6
3.000000
00:02:60.000000
```

Two minutes and sixty seconds. The route is right; it's exactly 180 seconds.
The time adds up to something like 179.99999 in floating point, the code
truncates it with `(int)` to get the minutes, gets 2, and then prints the
leftover, which `printf` rounds back up to 60. It had been printing that
since 2023. The fix rounds to milliseconds before splitting the time up. That baseline line is the only one the whole project was
allowed to change.

## One line per event

With the hooks in place, a new function, `run_trace`, prints one line for each
thing that happens. This is the real output for the map on the project page,
where road 2→4 drops to 5 km/h 30 seconds in:

```
pop 1 0.000
relax 1 2 60.000
relax 1 3 90.000
pop 2 60.000
relax 2 4 120.000
relax 2 5 210.000
...
plan 1 2 4 6 180.000
move 1 2 0.000 60.000
update 2 4 5.000 60.000
replan 2 60.000
pop 2 0.000
...
plan 2 5 6 180.000
move 2 5 60.000 210.000
move 5 6 210.000 240.000
done 240.000 4.000
```

Look at the times after `replan 2 60.000`. The next `pop 2` says `0.000`, and
the new plan says the trip takes `180.000`, but the car arrives at 240. Both
are right. When the car replans, Dijkstra starts again from node 2 with a
fresh clock, so everything it prints is relative to that moment. `move`,
`update` and `done` use the real clock. My own spec got this wrong: it had
the second plan at `240.000`, and I only fixed it after the real C
printed 180. The JavaScript keeps the clock of the last `replan` and adds it to every
Dijkstra event after it.

The trace also shows things the code never mentions. Node 5 is relaxed twice,
at 210 and then at 156, because our heap has no decrease-key. It just inserts
the node again and leaves the stale copy in the queue. And `pop 4 720.000`
shows up after the destination is already closed, because the loop doesn't
stop early. Both behaviours were in the code all along. I only saw them once
they were printed one per line.

## Reading a file that isn't a file

The original program reads its map with `fscanf` from a `FILE *`. A web page
has no file to hand it, and I didn't want a second parser just for the
browser. `fmemopen` solved that: it opens a string as a `FILE *`, so
`run_trace` takes the map as text and feeds it to the same three reader
functions the CLI uses. The only cost was compiling with `-std=gnu99`.

For the browser, Emscripten compiles every file except `main.c`. Without a
`main`, the module loads and waits. The page calls `run_trace` with the map as
a string, collects whatever it prints through the module's `print` callback,
and gets back the whole run as text. It's 49,687 bytes of WebAssembly, loaded
once per page, and a run on these maps takes a few milliseconds. When you add
a jam with the traffic editor, the page builds a new input and calls the C
again.

## Input from strangers

Before the traffic editor, the only input this program had ever read was
files the three of us wrote. Now it reads whatever a reader clicks together. Three things broke right away:

- `read_updates` read each line into `char aux[50]`, so a long line wrote past
  the end of the buffer.
- An update for a road that doesn't exist walked the adjacency list off its
  end and crashed.
- An unreachable destination crashed too, instead of saying so.

There was a fourth one, quieter. `dijkstra` sizes its arrays from the node
count in the file's first line, so a header claiming a billion nodes would
have blown the stack. `run_trace` now refuses anything above a million.

None of these were bugs for the assignment: we never fed it bad files. Each
one has a test now, and the CLI's output for the original maps still
matches the baseline byte for byte, apart from that one line.

## Playing it back

On the JavaScript side, the trace goes through a reducer that turns each event
into a full snapshot: which nodes are open or closed, the current plan, where
the car is. All of them are computed up front, so play, pause, step and speed
are just a position in an array. The canvas reads its colours from the site's
CSS variables on every frame, which is why the graph follows the light/dark
toggle mid-animation without any extra code.

The C itself still prints three minutes as `00:03:0.000000`, with the
seconds not zero-padded. The README documents it now, and I'm leaving it.
