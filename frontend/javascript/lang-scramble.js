import { criarEmbaralhador } from "./scramble.js"

// A mesma chave e lida pelo script inline de src/_partials/_head.erb, que
// esconde o texto antes do primeiro paint da pagina de destino.
const CHAVE = "lang-scramble"
const CLASSE = "lang-scramble"
const RAIZES = ".site-header, main, .site-footer"
const PULAR = "script, style, pre, code, textarea, noscript, canvas, [data-sem-scramble]"
const SAIDA_MS = 300
const ENTRADA_MS = 800

function movimentoReduzido() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches
}

function nosDeTextoNaTela() {
  const nos = []
  const alturaTela = window.innerHeight
  const alcance = document.createRange()

  for (const raiz of document.querySelectorAll(RAIZES)) {
    const andarilho = document.createTreeWalker(raiz, NodeFilter.SHOW_TEXT, {
      acceptNode(no) {
        if (!no.nodeValue.trim()) return NodeFilter.FILTER_REJECT
        if (no.parentElement.closest(PULAR)) return NodeFilter.FILTER_REJECT
        return NodeFilter.FILTER_ACCEPT
      },
    })
    let no
    while ((no = andarilho.nextNode())) {
      alcance.selectNodeContents(no)
      const caixa = alcance.getBoundingClientRect()
      if (caixa.width === 0 && caixa.height === 0) continue
      if (caixa.bottom < 0 || caixa.top > alturaTela) continue
      nos.push(no)
    }
  }
  return nos
}

function preparar(direcao) {
  return nosDeTextoNaTela().map((no) => ({
    no,
    original: no.nodeValue,
    quadro: criarEmbaralhador(no.nodeValue, { direcao }),
  }))
}

function marcarOcupado(ocupado) {
  for (const raiz of document.querySelectorAll(RAIZES)) {
    if (ocupado) raiz.setAttribute("aria-busy", "true")
    else raiz.removeAttribute("aria-busy")
  }
}

// Na saida o texto continua chacoalhando depois do progresso chegar a 1, ate
// `parar()`: a pagina antiga fica na tela ate a nova pintar, e um texto
// congelado em glifos aleatorios parece travamento.
function animar(itens, direcao, duracao) {
  let ativo = true
  let resolvido = false
  const pronto = new Promise((resolver) => {
    const inicio = performance.now()
    const passo = (agora) => {
      if (!ativo) return
      const p = Math.min(1, (agora - inicio) / duracao)
      for (const it of itens) it.no.nodeValue = it.quadro(p)
      if (p >= 1 && !resolvido) {
        resolvido = true
        resolver()
      }
      if (p < 1 || direcao === "saida") requestAnimationFrame(passo)
    }
    requestAnimationFrame(passo)
  })
  return { pronto, parar: () => { ativo = false } }
}

let saindo = false

function aoClicar(evento) {
  const link = evento.target.closest(".locale-switcher a")
  if (!link || evento.defaultPrevented || saindo) return
  if (evento.button !== 0 || evento.metaKey || evento.ctrlKey || evento.shiftKey || evento.altKey) return
  if (movimentoReduzido()) return

  evento.preventDefault()
  saindo = true
  try {
    sessionStorage.setItem(CHAVE, "1")
  } catch (e) {
    // sem sessionStorage a pagina de destino chega sem embaralhar; a saida ainda vale
  }

  const itens = preparar("saida")
  marcarOcupado(true)
  const anim = animar(itens, "saida", SAIDA_MS)

  // bfcache: ao voltar, a pagina e restaurada como estava — embaralhada.
  window.addEventListener("pageshow", (e) => {
    if (!e.persisted) return
    anim.parar()
    for (const it of itens) it.no.nodeValue = it.original
    marcarOcupado(false)
    saindo = false
  }, { once: true })

  anim.pronto.then(() => window.location.assign(link.href))
}

function chegar() {
  const html = document.documentElement
  if (!html.classList.contains(CLASSE)) return

  const itens = preparar("entrada")
  for (const it of itens) it.no.nodeValue = it.quadro(0)
  html.classList.remove(CLASSE)

  marcarOcupado(true)
  animar(itens, "entrada", ENTRADA_MS).pronto.then(() => marcarOcupado(false))
}

document.addEventListener("DOMContentLoaded", () => {
  chegar()
  document.addEventListener("click", aoClicar)
})
