import { criarEmbaralhador } from "./scramble.js"

const RAIZES = ".site-header, main, .site-footer"
const PULAR = "script, style, pre, code, textarea, noscript, canvas, [data-sem-scramble]"
const ATRIBUTOS = ["href", "hreflang", "lang", "alt", "title", "aria-label", "datetime"]
const DURACAO_MS = 700

function movimentoReduzido() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches
}

// Dentro de <noscript> o documento vivo guarda texto cru, mas o que vem do
// DOMParser (sem script) vira elementos de verdade; pular os dois lados e o
// que mantem as duas arvores pareaveis.
function elementos(raiz) {
  const lista = []
  const andarilho = raiz.ownerDocument.createTreeWalker(raiz, NodeFilter.SHOW_ELEMENT)
  let el
  while ((el = andarilho.nextNode())) {
    if (el.parentElement.closest("noscript")) continue
    lista.push(el)
  }
  return lista
}

function nosDeTexto(raiz) {
  const lista = []
  const andarilho = raiz.ownerDocument.createTreeWalker(raiz, NodeFilter.SHOW_TEXT)
  let no
  while ((no = andarilho.nextNode())) {
    if (!no.nodeValue.trim()) continue
    if (no.parentElement.closest(PULAR)) continue
    lista.push(no)
  }
  return lista
}

function parear(raizVelha, raizNova) {
  const ev = elementos(raizVelha)
  const en = elementos(raizNova)
  if (ev.length !== en.length) return null
  if (ev.some((el, i) => el.tagName !== en[i].tagName)) return null

  const tv = nosDeTexto(raizVelha)
  const tn = nosDeTexto(raizNova)
  if (tv.length !== tn.length) return null

  return {
    elementos: ev.map((el, i) => [el, en[i]]),
    textos: tv.map((no, i) => [no, tn[i].nodeValue]),
  }
}

function naTela(no) {
  const alcance = document.createRange()
  alcance.selectNodeContents(no)
  const caixa = alcance.getBoundingClientRect()
  if (caixa.width === 0 && caixa.height === 0) return false
  return caixa.bottom >= 0 && caixa.top <= window.innerHeight
}

function marcarOcupado(ocupado) {
  for (const raiz of document.querySelectorAll(RAIZES)) {
    if (ocupado) raiz.setAttribute("aria-busy", "true")
    else raiz.removeAttribute("aria-busy")
  }
}

function animar(itens) {
  return new Promise((resolver) => {
    const inicio = performance.now()
    const passo = (agora) => {
      const p = Math.min(1, (agora - inicio) / DURACAO_MS)
      for (const it of itens) it.no.nodeValue = it.quadro(p)
      if (p < 1) requestAnimationFrame(passo)
      else resolver()
    }
    requestAnimationFrame(passo)
  })
}

async function buscar(url) {
  const resposta = await fetch(url, { headers: { Accept: "text/html" } })
  if (!resposta.ok) throw new Error(`HTTP ${resposta.status}`)
  return new DOMParser().parseFromString(await resposta.text(), "text/html")
}

async function trocar(url, { empurrar }) {
  const doc = await buscar(url)
  const velhas = [...document.querySelectorAll(RAIZES)]
  const novas = [...doc.querySelectorAll(RAIZES)]
  if (velhas.length !== novas.length) throw new Error("raizes diferentes")

  const pares = velhas.map((raiz, i) => parear(raiz, novas[i]))
  if (pares.some((p) => p === null)) throw new Error("estrutura diferente")

  for (const { elementos: els } of pares) {
    for (const [velho, novo] of els) {
      for (const atributo of ATRIBUTOS) {
        if (novo.hasAttribute(atributo)) velho.setAttribute(atributo, novo.getAttribute(atributo))
      }
    }
  }
  document.title = doc.title
  document.documentElement.lang = doc.documentElement.lang
  if (empurrar) history.pushState(null, "", url)

  const itens = []
  for (const { textos } of pares) {
    for (const [no, novo] of textos) {
      if (no.nodeValue === novo) continue
      if (naTela(no)) itens.push({ no, quadro: criarEmbaralhador(no.nodeValue, novo) })
      else no.nodeValue = novo
    }
  }

  marcarOcupado(true)
  await animar(itens)
  marcarOcupado(false)
}

let trocando = false
let caminhoAtual = window.location.pathname

function executar(url, opcoes, fallback) {
  trocando = true
  trocar(url, opcoes)
    .then(() => { caminhoAtual = window.location.pathname })
    .catch(fallback)
    .finally(() => { trocando = false })
}

function aoClicar(evento) {
  const link = evento.target.closest(".locale-switcher a")
  if (!link || evento.defaultPrevented || trocando) return
  if (evento.button !== 0 || evento.metaKey || evento.ctrlKey || evento.shiftKey || evento.altKey) return
  if (movimentoReduzido()) return

  evento.preventDefault()
  executar(link.href, { empurrar: true }, () => window.location.assign(link.href))
}

function aoVoltar() {
  if (trocando || window.location.pathname === caminhoAtual) return
  executar(window.location.href, { empurrar: false }, () => window.location.reload())
}

document.addEventListener("DOMContentLoaded", () => {
  document.addEventListener("click", aoClicar)
  window.addEventListener("popstate", aoVoltar)
})
