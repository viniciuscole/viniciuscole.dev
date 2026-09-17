---
title: Routes under changing traffic, in C
locale: en
slug: car-routes
year: 2023
featured: true
order: 4
summary: Fastest path on a map whose traffic changes while the car is moving — Dijkstra with a priority queue, re-planned at every update, running here compiled to WebAssembly.
tech: [C, Dijkstra, Emscripten, WebAssembly]
repo: https://github.com/viniciuscole/car-routes-optimazing
demo:
  type: routes
---

A map is a graph: intersections are nodes, roads are directed edges, and
each road has a length in meters. What this project adds is time: roads
have a speed, and the speed **changes while the car is driving** — a
traffic jam at 8:07am, a lane opening up at 8:20am. The program takes the
map, the origin, the destination, and the list of changes, and answers
where to go and how long it takes.

The simulation above runs the project's original C code, compiled to
WebAssembly. Hit **Run** to watch the algorithm pick a path and the car
follow it — and, when road 2→4 jams, watch the detour. Click any road to
make your own traffic jam.

## Weight is time, not distance

The shortest path isn't the fastest one: 3 km at 60 km/h take 3 minutes;
4 km at 90 km/h, 2 minutes 40. So the weight of each edge is the time it
costs, computed once when the file is read:

```c
double calculate_weight(double distance, double velocity)
{
    velocity = velocity / 3.6;
    return distance / velocity;
}
```

Meters over (km/h ÷ 3.6) gives seconds. When a road's speed changes, only
that number changes; the graph stays the same.

## Dijkstra, step by step

<div class="rotas" data-rotas="dijkstra"></div>

Dijkstra keeps, for each node, the shortest known time to reach it, and a
queue of the nodes still open, ordered by that time. At each step it pulls
the node with the smallest time off the queue, **closes** it — from then
on its time never changes again — and looks at its neighbors: if reaching
them through this node is faster than what was known before, the
neighbor's time is updated and it goes back into the queue. That's
*relaxation*, and in the code it looks like this:

```c
if (time[w_id] > time[v_id] + value(adj))
{
    time[w_id] = time[v_id] + value(adj);
    dist[w_id] = dist[v_id] + dist(adj);
    path[w_id] = v_id;
    PQ_insert(pq, init_adj(w_id, dist[w_id], time[w_id]));
}
```

`path[w] = v` stores where `w` was reached from; at the end, walking
backward from the destination rebuilds the path. The invariant that makes
it all work: once a node leaves the queue, no still-unexplored path can be
faster to reach it — because every other node left in the queue already
costs more, and roads only ever add time. That requires positive weights,
and time always is.

In the simulation, nodes with a highlighted outline are in the queue; the
filled ones are closed. Notice the algorithm doesn't stop once the
destination is closed: it empties the whole queue. That's an optimization
left out.

## The priority queue

The queue is a binary min-heap (`PQ.c`): insert and remove both cost
O(log n). Without it, finding the smallest time would be a linear search
at every step, and the whole algorithm would run in O(V²). With the heap,
O((V + E) log V) — for a city map, the difference between seconds and
milliseconds.

One detail of the project: the heap doesn't use a "decrease-key"
operation. When a
node's time improves, it's inserted again, and the old copy stays in the
queue with the stale time. When it comes out, it's ignored because the
node is already closed. It's simpler and cheap: the queue grows to as many
as E entries instead of V.

## When traffic changes

<div class="rotas" data-rotas="engarrafamento"></div>

Here's what the project actually asks for. The car sets out on `1 2 4 6`,
the fastest plan: 3 km, 3 minutes. At 30 seconds, road 2→4 drops to
5 km/h. The car only finds out on reaching 2, at 60 seconds — and then the
program applies the change and **runs Dijkstra again, from 2**. Road 2→4
now costs 12 minutes; `2 5 6` costs 3. The car takes the detour and
arrives in 4 minutes, having driven 4 km.

The loop that does this is in `calculate_path`: it walks the plan node by
node, adding up time; when the clock passes the instant of the next
update, it applies every update that's due and replans from where it is.

<div class="rotas" data-rotas="tarde-demais"></div>

Sometimes there isn't time. In this scenario the same road jams at
90 seconds — and the car entered it at 60. The model doesn't interrupt a
road partway through: the update is only applied when the car reaches the
next node, at 4, at 120 seconds. By then it no longer matters: `4 6` is
the only path left. Traffic changed and the car paid for it with no
chance to react. It's the model's most honest limitation, and its most
real one.

<div class="rotas" data-rotas="via-libera"></div>

The opposite happens too. With everything at 30 km/h, the plan is
`1 2 4 6`, 6 minutes. At 60 seconds, road 2→5 opens up at 120 km/h. The car reaches 2
at 2 minutes, replans, and `2 5 6` now costs 2 min 15 against 4 minutes
through 4. It takes the detour and saves almost two minutes.

## What I would do differently

- **Recomputing from scratch** on every update is simple and, for graphs
  this size, instant. On a real map, incremental algorithms like D\* Lite
  or LPA\* reuse the previous search and only fix what the change
  affected.
- **The program reads the future**: all the updates come from the file,
  each with its instant already marked. A real car only learns about a
  jam when it happens — but the Dijkstra it runs on every piece of news is
  exactly the one described here.
- **A single initial speed** for every road. One more column in the file
  would be enough to give each road its own.
- **The car never turns back**. If the best move were to reverse on the
  road it's on, the model doesn't know it.

## Credits

A project for Search and Sorting Techniques (UFES, 2023), built with
[João](https://github.com/vortex2jm) and
[Gabriel Gatti](https://github.com/gabrielgatti7). The code is in the
[repository](https://github.com/viniciuscole/car-routes-optimazing); the
*trace* mode that feeds these simulations was added for this page.
