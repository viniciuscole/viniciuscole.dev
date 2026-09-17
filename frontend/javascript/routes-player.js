import { gerarEntrada, chaveAresta } from "./routes-entrada.js"
import { analisar, estadoInicial, reduzir, duracaoMs } from "./routes-trace.js"
import { criarSimulador, carregarScriptNoNavegador } from "./routes-wasm.js"
import { desenhar } from "./routes-desenho.js"

const simulador = criarSimulador({ carregarScript: carregarScriptNoNavegador })
let cenariosPromessa = null

function carregarCenarios(base) {
  if (!cenariosPromessa) cenariosPromessa = fetch(`${base}/cenarios.json`).then((r) => r.json())
  return cenariosPromessa
}

function tema() {
  const estilo = getComputedStyle(document.documentElement)
  const cor = (nome) => estilo.getPropertyValue(nome).trim()
  return { bg: cor("--bg"), bgSutil: cor("--bg-sutil"), fg: cor("--fg"), muted: cor("--muted"), accent: cor("--accent"), border: cor("--border") }
}

function textosDe(raiz) {
  const proprio = raiz.getAttribute("data-rotas-textos")
  const fonte = proprio ? raiz : document.querySelector("[data-rotas-textos]")
  return fonte ? JSON.parse(fonte.getAttribute("data-rotas-textos")) : {}
}

function botao(texto, aoClicar) {
  const b = document.createElement("button")
  b.type = "button"
  b.textContent = texto
  b.addEventListener("click", aoClicar)
  return b
}

function relogioTexto(segundos) {
  const s = Math.max(0, Math.round(segundos))
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`
}

export function montar(raiz) {
  const id = raiz.getAttribute("data-rotas")
  const base = raiz.getAttribute("data-rotas-base") || document.querySelector("[data-rotas-base]")?.getAttribute("data-rotas-base") || "/demos/car-routes"
  const garantir = (gancho, tag, classe) => {
    let el = raiz.querySelector(`[${gancho}]`)
    if (!el) {
      el = document.createElement(tag)
      el.setAttribute(gancho, "")
      if (classe) el.className = classe
      raiz.append(el)
    }
    return el
  }
  const canvas = garantir("data-rotas-canvas", "canvas")
  const controles = garantir("data-rotas-controles", "div", "rotas-controles")
  const painel = garantir("data-rotas-painel", "aside", "rotas-painel")
  const erro = raiz.querySelector("[data-rotas-erro]")
  const t = textosDe(raiz)
  const ctx = canvas.getContext("2d")

  let cenario = null
  let eventos = []
  let estados = []
  let indice = 0
  let decorrido = 0
  let escala = 1
  let rodando = false
  let carregando = false
  let ultimoQuadro = 0
  let geracao = 0

  const btRodar = botao(t.play, () => (rodando ? pausar() : rodar()))
  btRodar.disabled = true
  const btPasso = botao(t.step, () => passo())
  const btVelocidade = botao(`${t.speed} 1×`, () => { escala = escala === 1 ? 4 : 1; btVelocidade.textContent = `${t.speed} ${escala}×` })
  const btReiniciar = botao(t.restart, () => reiniciar())
  controles.replaceChildren(btRodar, btPasso, btVelocidade, btReiniciar)

  const dl = document.createElement("dl")
  const ddRelogio = document.createElement("dd")
  const ddFila = document.createElement("dd")
  ddFila.className = "rotas-fila"
  const ddKm = document.createElement("dd")
  for (const [rotulo, dd] of [[t.clock, ddRelogio], [t.queue, ddFila], [t.km, ddKm]]) {
    const dt = document.createElement("dt")
    dt.textContent = rotulo
    dl.append(dt, dd)
  }
  const legenda = document.createElement("p")
  legenda.className = "rotas-legenda"
  for (const [classe, texto] of [["aberto", t.legend_open], ["fechado", t.legend_closed], ["planejado", t.legend_planned], ["percorrido", t.legend_driven]]) {
    const span = document.createElement("span")
    span.className = classe
    span.textContent = texto
    legenda.append(span)
  }
  painel.replaceChildren(dl, legenda)
  const aviso = document.createElement("p")
  aviso.className = "rotas-aviso"
  aviso.setAttribute("data-rotas-aviso", "")
  aviso.hidden = true
  painel.append(aviso)

  function tamanho() {
    const dpr = window.devicePixelRatio || 1
    const largura = canvas.clientWidth
    const altura = Math.round(largura * 2 / 3)
    if (canvas.width !== largura * dpr || canvas.height !== altura * dpr) {
      canvas.width = largura * dpr
      canvas.height = altura * dpr
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    return { largura, altura }
  }

  function estadoAtual() {
    return estados[Math.min(indice, estados.length - 1)]
  }

  function quadro() {
    if (!cenario) return
    const { largura, altura } = tamanho()
    const e = eventos[indice]
    const dur = e ? duracaoMs(e, escala) : 0
    const progresso = e && e.tipo === "move" && dur > 0 ? Math.min(1, decorrido / dur) : 1
    const s = estadoAtual()
    const visivel = e && e.tipo === "move" ? { ...s, carro: { de: e.de, para: e.para, t0: e.t0, t1: e.t1 } } : s
    desenhar(ctx, cenario, visivel, progresso, tema(), largura, altura)
    const relogio = e && e.tipo === "move" ? e.t0 + (e.t1 - e.t0) * progresso : s.relogio
    ddRelogio.textContent = relogioTexto(relogio)
    raiz.setAttribute("data-rotas-relogio", String(Math.round(relogio)))
    ddFila.replaceChildren(...[...s.abertos].sort((a, b) => a[1] - b[1]).map(([no, tempo]) => {
      const span = document.createElement("span")
      span.textContent = `${no}: ${relogioTexto(s.base + tempo)}`
      return span
    }))
    ddKm.textContent = s.fim ? `${s.fim.km.toFixed(1)} · ${relogioTexto(s.fim.t)}` : ""
  }

  function avancar() {
    if (indice >= eventos.length) return
    indice++
    decorrido = 0
    if (indice >= eventos.length) terminar()
    quadro()
  }

  function terminar() {
    rodando = false
    btRodar.textContent = t.play
    btRodar.setAttribute("aria-pressed", "false")
    const s = estadoAtual()
    raiz.setAttribute("data-rotas-estado", s.inalcancavel ? "erro" : "fim")
    raiz.setAttribute("data-rotas-caminho", s.percorrido.join(" "))
    if (s.inalcancavel) { aviso.textContent = t.unreachable; aviso.hidden = false }
  }

  function laco(agora) {
    if (!rodando) return
    decorrido += agora - ultimoQuadro
    ultimoQuadro = agora
    const e = eventos[indice]
    if (e && decorrido >= duracaoMs(e, escala)) {
      avancar()
      if (!rodando) return
    }
    quadro()
    requestAnimationFrame(laco)
  }

  async function garantirTrace() {
    if (eventos.length > 0) return true
    carregando = true
    btRodar.disabled = true
    try {
      return await carregarTrace()
    } catch (motivo) {
      console.error("[rotas]", motivo)
      raiz.setAttribute("data-rotas-estado", "erro")
      if (erro) erro.hidden = false
      return false
    } finally {
      carregando = false
      btRodar.disabled = false
    }
  }

  async function rodar() {
    if (rodando || carregando) return
    if (!(await garantirTrace())) return
    if (indice >= eventos.length) reiniciar()
    rodando = true
    btRodar.textContent = t.pause
    btRodar.setAttribute("aria-pressed", "true")
    raiz.setAttribute("data-rotas-estado", "rodando")
    ultimoQuadro = performance.now()
    requestAnimationFrame(laco)
  }

  async function passo() {
    if (!(await garantirTrace())) return
    pausar()
    avancar()
  }

  function pausar() {
    rodando = false
    btRodar.textContent = t.play
    btRodar.setAttribute("aria-pressed", "false")
    if (eventos.length) raiz.setAttribute("data-rotas-estado", "pausado")
  }

  function reiniciar() {
    pausar()
    indice = 0
    decorrido = 0
    raiz.removeAttribute("data-rotas-caminho")
    raiz.setAttribute("data-rotas-estado", eventos.length ? "pausado" : "pronto")
    aviso.hidden = true
    if (erro) erro.hidden = true
    quadro()
  }

  async function carregarTrace() {
    const minha = geracao
    const trace = await simulador.rodar(gerarEntrada(cenario), base)
    if (minha !== geracao) return false
    eventos = analisar(trace)
    estados = [estadoInicial(eventos)]
    for (const e of eventos) estados.push(reduzir(estados.at(-1), e))
    indice = 0
    decorrido = 0
    return true
  }

  function definirCenario(novo) {
    geracao++
    cenario = novo
    eventos = []
    estados = [estadoInicial([])]
    for (const a of novo.arestas) estados[0].arestas.set(chaveAresta(a.de, a.para), { de: a.de, para: a.para, m: a.m, kmh: novo.kmh })
    reiniciar()
    btRodar.disabled = false
  }

  raiz.__rotas = { rodar, pausar, passo, reiniciar, definirCenario, cenarioAtual: () => cenario }
  window.addEventListener("resize", quadro)

  carregarCenarios(base)
    .then((cenarios) => {
      if (!cenarios[id]) throw new Error(`cenario ${id} nao existe`)
      definirCenario(structuredClone(cenarios[id]))
    })
    .catch((motivo) => {
      console.error("[rotas]", motivo)
      raiz.setAttribute("data-rotas-estado", "erro")
      if (erro) erro.hidden = false
    })
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-rotas]").forEach(montar)
})
