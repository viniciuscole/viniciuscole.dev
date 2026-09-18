import { test } from "node:test"
import assert from "node:assert/strict"
import { GLIFOS, criarEmbaralhador } from "../../frontend/javascript/scramble.js"

const TEXTO = "Notes on things I build."

function fixo(valor) {
  return () => valor
}

function ehGlifo(c) {
  return GLIFOS.includes(c)
}

test("entrada: em 0 nada esta resolvido, em 1 o texto final aparece inteiro", () => {
  const quadro = criarEmbaralhador(TEXTO, { direcao: "entrada", aleatorio: fixo(0.5) })
  const inicio = quadro(0)
  assert.equal(inicio.length, TEXTO.length)
  for (let i = 0; i < TEXTO.length; i++) {
    if (/\s/.test(TEXTO[i])) assert.equal(inicio[i], TEXTO[i])
    else assert.ok(ehGlifo(inicio[i]), `posicao ${i} deveria ser um glifo, veio ${JSON.stringify(inicio[i])}`)
  }
  assert.equal(quadro(1), TEXTO)
})

test("entrada: uma letra resolvida nao volta a embaralhar", () => {
  const texto = "ñõçãõ é ãçãõ — ïñíçíõ!"
  assert.ok([...texto].every((c) => /\s/.test(c) || !ehGlifo(c)))
  const quadro = criarEmbaralhador(texto, { direcao: "entrada" })
  let anterior = quadro(0)
  for (let p = 0.05; p <= 1; p += 0.05) {
    const atual = quadro(p)
    for (let i = 0; i < texto.length; i++) {
      if (anterior[i] === texto[i]) assert.equal(atual[i], texto[i], `posicao ${i} regrediu em p=${p}`)
    }
    anterior = atual
  }
})

test("entrada: resolve da esquerda para a direita", () => {
  const quadro = criarEmbaralhador("abcdefghij", { direcao: "entrada", aleatorio: fixo(0) })
  const meio = quadro(0.5)
  const resolvidos = [...meio].map((c, i) => c === "abcdefghij"[i])
  const primeiroPendente = resolvidos.indexOf(false)
  assert.ok(primeiroPendente > 0)
  assert.ok(resolvidos.slice(0, primeiroPendente).every(Boolean))
  assert.ok(resolvidos.slice(primeiroPendente).every((r) => !r))
})

test("saida: em 0 o texto esta intacto, em 1 so restam glifos e espacos", () => {
  const quadro = criarEmbaralhador(TEXTO, { direcao: "saida", aleatorio: fixo(0.5) })
  assert.equal(quadro(0), TEXTO)
  const fim = quadro(1)
  for (let i = 0; i < TEXTO.length; i++) {
    if (/\s/.test(TEXTO[i])) assert.equal(fim[i], TEXTO[i])
    else assert.ok(ehGlifo(fim[i]))
  }
})

test("espaco em branco nunca vira glifo, em nenhuma direcao", () => {
  const texto = "a b\tc\nd"
  for (const direcao of ["entrada", "saida"]) {
    const quadro = criarEmbaralhador(texto, { direcao })
    for (const p of [0, 0.3, 0.7, 1]) {
      const q = quadro(p)
      assert.equal(q[1], " ")
      assert.equal(q[3], "\t")
      assert.equal(q[5], "\n")
    }
  }
})

test("glifos usam o aleatorio injetado", () => {
  const quadro = criarEmbaralhador("xyz", { direcao: "entrada", aleatorio: fixo(0) })
  assert.equal(quadro(0), GLIFOS[0].repeat(3))
})
