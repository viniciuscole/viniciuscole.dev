import { test } from "node:test"
import assert from "node:assert/strict"
import { criarEmbaralhador } from "../../frontend/javascript/scramble.js"

function fixo(valor) {
  return () => valor
}

const ASCII = /^[A-Za-z0-9]$/

// Letras fora do ASCII nunca saem do sorteio, entao da para distinguir
// "ainda e o texto antigo" / "ja e o novo" / "glifo" so olhando o caractere.
const DE = "ñõçãõéãçãõ"
const PARA = "ÑÕÇÃÕÉÃÇÃÕ"

test("em 0 mostra o texto antigo inteiro, em 1 o novo inteiro, mesmo com tamanhos diferentes", () => {
  const quadro = criarEmbaralhador("Home", "Início", { aleatorio: fixo(0.5) })
  assert.equal(quadro(0), "Home")
  assert.equal(quadro(1), "Início")

  const encolhe = criarEmbaralhador("Projetos", "Blog", { aleatorio: fixo(0.5) })
  assert.equal(encolhe(0), "Projetos")
  assert.equal(encolhe(1), "Blog")
})

test("no meio, so uma faixa de letras esta embaralhada; antes dela ja e o novo, depois ainda e o antigo", () => {
  const quadro = criarEmbaralhador(DE, PARA, { aleatorio: fixo(0) })
  const meio = [...quadro(0.5)]
  const de = [...DE]
  const para = [...PARA]

  const estados = meio.map((c, i) => (ASCII.test(c) ? "glifo" : c === para[i] ? "novo" : c === de[i] ? "antigo" : "?"))
  assert.ok(!estados.includes("?"))
  const primeiroGlifo = estados.indexOf("glifo")
  const ultimoGlifo = estados.lastIndexOf("glifo")
  assert.ok(primeiroGlifo > 0, "esperava letras ja resolvidas antes da faixa")
  assert.ok(ultimoGlifo < estados.length - 1, "esperava letras ainda antigas depois da faixa")
  assert.ok(estados.slice(0, primeiroGlifo).every((e) => e !== "antigo"), "antes da faixa ainda ha texto antigo")
  assert.ok(estados.slice(ultimoGlifo + 1).every((e) => e !== "novo"), "depois da faixa ja ha texto novo")

  const embaralhadas = estados.filter((e) => e === "glifo").length
  assert.ok(embaralhadas <= estados.length * 0.4, `faixa larga demais: ${embaralhadas} de ${estados.length}`)
})

test("uma letra que chegou ao texto novo nao volta atras", () => {
  const quadro = criarEmbaralhador(DE, PARA)
  const para = [...PARA]
  let anterior = [...quadro(0)]
  for (let p = 0.05; p <= 1.0001; p += 0.05) {
    const atual = [...quadro(p)]
    for (let i = 0; i < para.length; i++) {
      if (anterior[i] === para[i]) {
        assert.equal(atual[i], para[i], `posicao ${i} regrediu em p=${p}`)
      }
    }
    anterior = atual
  }
})

test("o glifo tem a mesma classe da letra que vai substituir", () => {
  const para = "Ab1 ç"
  const quadro = criarEmbaralhador("ñõçãõ", para, { aleatorio: fixo(0) })
  // com sorteio 0 a janela da posicao i comeca em i/4*0.55; um pouco depois
  // disso a letra esta embaralhada
  const classes = [/[A-Z]/, /[a-z]/, /[0-9]/, / /, /[a-z]/]
  classes.forEach((classe, i) => {
    const letra = [...quadro((i / 4) * 0.55 + 0.05)][i]
    assert.match(letra, classe, `posicao ${i} (${JSON.stringify(para[i])}) virou ${JSON.stringify(letra)}`)
  })
})

test("espaco em branco do texto novo nunca vira glifo", () => {
  const quadro = criarEmbaralhador("aaaa", "a b\tc", { aleatorio: fixo(0) })
  for (const p of [0.2, 0.4, 0.6, 0.8]) {
    const q = [...quadro(p)]
    assert.ok([" ", "a"].includes(q[1]), `p=${p}: ${JSON.stringify(q[1])}`)
    assert.ok(["\t", "a"].includes(q[3]), `p=${p}: ${JSON.stringify(q[3])}`)
  }
  assert.equal(quadro(1), "a b\tc")
})

test("o glifo persiste entre quadros e so troca quando o sorteio manda", () => {
  // varia o suficiente para sortear glifos diferentes, mas nunca cai abaixo
  // do limiar de troca
  const ciclo = [0.5, 0.7, 0.9, 0.4, 0.6]
  let chamadas = 0
  const aleatorio = () => ciclo[chamadas++ % ciclo.length]
  const quadro = criarEmbaralhador("ñõçãõéãçãõ", "ÑÕÇÃÕÉÃÇÃÕ", { aleatorio })
  const a = quadro(0.5)
  const b = quadro(0.5)
  assert.equal(a, b, "sem sorteio abaixo do limiar de troca, o glifo deve ficar igual")
})

test("o glifo vem da mesma classe de largura da letra nova", () => {
  const para = "iWmIaE"
  const quadro = criarEmbaralhador("ñõçãõé", para, { aleatorio: fixo(0.5) })
  const esperado = [/[ijlt]/, /[MW]/, /[mw]/, /[IJ]/, /[abcdeghknopqsuvxyz]/, /[ABCDEFGHKLNOPQRSTUVXYZ]/]
  esperado.forEach((classe, i) => {
    const letra = [...quadro((i / 5) * 0.55 + 0.1 + 0.05)][i]
    assert.match(letra, classe, `posicao ${i} (${para[i]}) virou ${JSON.stringify(letra)}`)
  })
})
