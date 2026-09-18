import { test } from "node:test"
import assert from "node:assert/strict"
import { gerarEntrada, chaveAresta } from "../../frontend/javascript/routes-entrada.js"

const cenario = {
  nos: [{ id: 1, x: 0, y: 0 }, { id: 2, x: 1, y: 0 }, { id: 3, x: 1, y: 1 }],
  arestas: [{ de: 1, para: 2, m: 1000 }, { de: 2, para: 3, m: 500 }],
  origem: 1, destino: 3, kmh: 60,
  atualizacoes: [{ t: 30, de: 2, para: 3, kmh: 5 }],
}

test("gera o formato do trabalho", () => {
  assert.equal(gerarEntrada(cenario), "3;2\n1;3\n60\n1;2;1000\n2;3;500\n30;2;3;5\n")
})

test("sem atualizacoes termina apos as arestas", () => {
  assert.equal(gerarEntrada({ ...cenario, atualizacoes: [] }), "3;2\n1;3\n60\n1;2;1000\n2;3;500\n")
})

test("ordena as atualizacoes por instante", () => {
  const dois = { ...cenario, atualizacoes: [{ t: 90, de: 1, para: 2, kmh: 10 }, { t: 30, de: 2, para: 3, kmh: 5 }] }
  assert.match(gerarEntrada(dois), /30;2;3;5\n90;1;2;10\n$/)
})

test("chaveAresta", () => {
  assert.equal(chaveAresta(2, 3), "2-3")
})
