import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { createRequire } from "node:module"
import { fileURLToPath } from "node:url"
import { dirname, join } from "node:path"
import { criarSimulador } from "../../frontend/javascript/routes-wasm.js"
import { gerarEntrada } from "../../frontend/javascript/routes-entrada.js"

const require = createRequire(import.meta.url)
const dir = join(dirname(fileURLToPath(import.meta.url)), "../../src/demos/car-routes")
// package.json declara "type":"module": o loader UMD do Emscripten so vira exportavel se avaliado como CommonJS
const carregarScript = async () => {
  const src = readFileSync(join(dir, "rotas.js"), "utf8")
  const mod = { exports: {} }
  new Function("module", "exports", "require", "__dirname", "__filename", src)(mod, mod.exports, require, dir, join(dir, "rotas.js"))
  return mod.exports
}
const cenarios = JSON.parse(readFileSync(join(dir, "cenarios.json")))

test("roda o cenario engarrafamento e termina em done", async () => {
  const sim = criarSimulador({ carregarScript })
  const trace = await sim.rodar(gerarEntrada(cenarios.engarrafamento))
  const linhas = trace.trim().split("\n")
  assert.equal(linhas[0], "graph 6 9")
  assert.equal(linhas.at(-1), "done 240.000 4.000")
  assert.ok(linhas.includes("plan 2 5 6 180.000"))
})

test("duas rodadas seguidas nao misturam a saida", async () => {
  const sim = criarSimulador({ carregarScript })
  const a = await sim.rodar(gerarEntrada(cenarios.engarrafamento))
  const b = await sim.rodar(gerarEntrada(cenarios["tarde-demais"]))
  assert.equal(a.match(/^done/gm).length, 1)
  assert.equal(b.match(/^done/gm).length, 1)
  assert.notEqual(a, b)
})

test("entrada invalida rejeita", async () => {
  const sim = criarSimulador({ carregarScript })
  await assert.rejects(sim.rodar("0;0\n1;1\n0\n"))
})

test("uma instanciacao rejeitada nao fica em cache para sempre", async () => {
  let chamadas = 0
  const falhaUmaVez = async (url) => {
    chamadas++
    if (chamadas === 1) throw new Error("falha simulada de carregamento")
    return carregarScript(url)
  }
  const sim = criarSimulador({ carregarScript: falhaUmaVez })
  await assert.rejects(sim.rodar(gerarEntrada(cenarios.engarrafamento)))
  const trace = await sim.rodar(gerarEntrada(cenarios.engarrafamento))
  assert.equal(trace.trim().split("\n").at(-1), "done 240.000 4.000")
})

test("duas rodadas concorrentes instanciam o modulo uma vez so", async () => {
  let instancias = 0
  const contando = async () => {
    instancias++
    return carregarScript()
  }
  const sim = criarSimulador({ carregarScript: contando })
  const [a, b] = await Promise.all([
    sim.rodar(gerarEntrada(cenarios.engarrafamento)),
    sim.rodar(gerarEntrada(cenarios["tarde-demais"])),
  ])
  assert.equal(instancias, 1)
  assert.equal(a.match(/^done/gm).length, 1)
  assert.equal(b.match(/^done/gm).length, 1)
  assert.notEqual(a, b)
})
