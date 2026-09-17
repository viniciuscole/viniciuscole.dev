import { test } from "node:test"
import assert from "node:assert/strict"
import { analisar, estadoInicial, reduzir, duracaoMs } from "../../frontend/javascript/routes-trace.js"

const TRACE = `graph 3 2
edge 1 2 1000 60.000
edge 2 3 500 60.000
replan 1 0.000
pop 1 0.000
relax 1 2 60.000
pop 2 60.000
relax 2 3 90.000
pop 3 90.000
plan 1 2 3 90.000
move 1 2 0.000 60.000
update 2 3 5.000 60.000
replan 2 60.000
pop 2 0.000
relax 2 3 360.000
pop 3 360.000
plan 2 3 360.000
move 2 3 60.000 420.000
done 420.000 1.500
`

test("analisar converte cada linha num evento tipado", () => {
  const ev = analisar(TRACE)
  assert.equal(ev.length, 19)
  assert.deepEqual(ev[0], { tipo: "graph", n: 3, e: 2 })
  assert.deepEqual(ev[1], { tipo: "edge", de: 1, para: 2, m: 1000, kmh: 60 })
  assert.deepEqual(ev[9], { tipo: "plan", caminho: [1, 2, 3], eta: 90 })
  assert.deepEqual(ev[10], { tipo: "move", de: 1, para: 2, t0: 0, t1: 60 })
  assert.deepEqual(ev[11], { tipo: "update", de: 2, para: 3, kmh: 5, t: 60 })
  assert.deepEqual(ev[18], { tipo: "done", t: 420, km: 1.5 })
})

test("plan com destino inalcancavel tem eta null", () => {
  assert.deepEqual(analisar("plan 3 unreachable\n")[0], { tipo: "plan", caminho: [3], eta: null })
})

test("estadoInicial carrega as arestas e mais nada", () => {
  const s = estadoInicial(analisar(TRACE))
  assert.equal(s.arestas.size, 2)
  assert.deepEqual(s.arestas.get("2-3"), { de: 2, para: 3, m: 500, kmh: 60 })
  assert.equal(s.relogio, 0)
  assert.deepEqual([...s.fechados], [])
  assert.equal(s.carro, null)
})

test("reduzir acompanha o Dijkstra e o carro", () => {
  const ev = analisar(TRACE)
  let s = estadoInicial(ev)
  for (const e of ev.slice(0, 10)) s = reduzir(s, e)
  assert.deepEqual([...s.fechados].sort(), [1, 2, 3])
  assert.deepEqual(s.planejado, [1, 2, 3])
  s = reduzir(s, ev[10])
  assert.deepEqual(s.percorrido, [1, 2])
  assert.deepEqual(s.carro, { de: 1, para: 2, t0: 0, t1: 60 })
  assert.equal(s.relogio, 60)
  s = reduzir(s, ev[11])
  assert.equal(s.arestas.get("2-3").kmh, 5)
  assert.deepEqual(s.atualizada, { de: 2, para: 3, t: 60 })
  s = reduzir(s, ev[12])
  assert.deepEqual([...s.fechados], [])
  assert.equal(s.base, 60)
  assert.deepEqual(s.planejado, [])
})

test("abertos guarda o tempo do relax e sai no pop", () => {
  const ev = analisar(TRACE)
  let s = estadoInicial(ev)
  for (const e of ev.slice(0, 6)) s = reduzir(s, e)
  assert.deepEqual([...s.abertos], [[2, 60]])
  s = reduzir(s, ev[6])
  assert.deepEqual([...s.abertos], [])
  s = reduzir(s, ev[7])
  assert.deepEqual([...s.abertos], [[3, 90]])
})

test("done fecha o estado", () => {
  const ev = analisar(TRACE)
  const s = ev.reduce(reduzir, estadoInicial(ev))
  assert.deepEqual(s.fim, { t: 420, km: 1.5 })
  assert.deepEqual(s.percorrido, [1, 2, 3])
})

test("reduzir nao muta o estado anterior", () => {
  const ev = analisar(TRACE)
  const a = estadoInicial(ev)
  reduzir(a, ev[11])
  assert.equal(a.arestas.get("2-3").kmh, 60)
})

test("duracaoMs", () => {
  assert.equal(duracaoMs({ tipo: "pop" }, 1), 250)
  assert.equal(duracaoMs({ tipo: "move", t0: 0, t1: 60 }, 1), 1000)
  assert.equal(duracaoMs({ tipo: "move", t0: 0, t1: 60 }, 4), 250)
  assert.equal(duracaoMs({ tipo: "done" }, 1), 0)
})
