import { test } from "node:test"
import assert from "node:assert/strict"
import { desenhar, posicao, arestaMaisProxima } from "../../frontend/javascript/routes-desenho.js"
import { analisar, estadoInicial, reduzir } from "../../frontend/javascript/routes-trace.js"

const cenario = {
  nos: [{ id: 1, x: 0, y: 0.5 }, { id: 2, x: 0.5, y: 0.5 }, { id: 3, x: 1, y: 0.5 }],
  arestas: [{ de: 1, para: 2, m: 1000 }, { de: 2, para: 3, m: 500 }],
  origem: 1, destino: 3, kmh: 60, atualizacoes: [],
}
const tema = { bg: "#fff", fg: "#000", muted: "#888", accent: "#c00", border: "#ccc", bgSutil: "#eee" }

function gravador() {
  const chamadas = []
  const ctx = new Proxy({}, {
    get: (_, nome) => (nome === "chamadas" ? chamadas : (...args) => { chamadas.push([nome, ...args]); return ctx }),
    set: (_, nome, valor) => { chamadas.push(["set", nome, valor]); return true },
  })
  return ctx
}

test("posicao respeita a margem", () => {
  assert.deepEqual(posicao(cenario, 1, 300, 200), { x: 24, y: 100 })
  assert.deepEqual(posicao(cenario, 3, 300, 200), { x: 276, y: 100 })
})

test("desenha um arco por no e uma linha por aresta", () => {
  const ctx = gravador()
  const ev = analisar("graph 3 2\nedge 1 2 1000 60.000\nedge 2 3 500 60.000\n")
  desenhar(ctx, cenario, estadoInicial(ev), 0, tema, 300, 200)
  assert.equal(ctx.chamadas.filter((c) => c[0] === "arc").length, 3)
  assert.equal(ctx.chamadas.filter((c) => c[0] === "lineTo").length >= 2, true)
})

test("o carro fica no meio da via com progresso 0.5", () => {
  const ctx = gravador()
  const ev = analisar("graph 3 2\nedge 1 2 1000 60.000\nedge 2 3 500 60.000\nmove 1 2 0.000 60.000\n")
  const estado = ev.reduce(reduzir, estadoInicial(ev))
  desenhar(ctx, cenario, estado, 0.5, tema, 300, 200)
  const arcos = ctx.chamadas.filter((c) => c[0] === "arc")
  const carro = arcos.at(-1)
  assert.equal(carro[1], 87)
  assert.equal(carro[2], 100)
})

test("arestaMaisProxima acha a via sob o ponto e ignora o longe", () => {
  assert.deepEqual(arestaMaisProxima(cenario, 87, 104, 300, 200), { de: 1, para: 2 })
  assert.equal(arestaMaisProxima(cenario, 87, 160, 300, 200), null)
})
