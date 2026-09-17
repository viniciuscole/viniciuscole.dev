import { gerarEntrada, chaveAresta } from "./routes-entrada.js"
import { analisar, estadoInicial, reduzir, duracaoMs, eventosVisiveis } from "./routes-trace.js"
import { criarSimulador, carregarScriptNoNavegador } from "./routes-wasm.js"
import { desenhar, arestaMaisProxima } from "./routes-desenho.js"

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

function montarEditor(raiz, canvas, painel, t) {
  const original = structuredClone(raiz.__rotas.cenarioAtual())
  let cenario = structuredClone(original)
  let selecionada = null

  const caixa = document.createElement("div")
  caixa.className = "rotas-editor"
  const dica = document.createElement("p")
  dica.textContent = t.editor_hint
  const form = document.createElement("form")
  form.setAttribute("data-rotas-editor-form", "")
  form.hidden = true
  const rotulo = document.createElement("strong")
  const campo = (nome, texto, valor) => {
    const label = document.createElement("label")
    label.textContent = texto
    const input = document.createElement("input")
    input.name = nome
    input.type = "number"
    input.min = "0"
    input.step = "1"
    input.value = valor
    input.required = true
    label.append(input)
    return label
  }
  const instante = campo("instante", t.instant, "0")
  const kmh = campo("kmh", t.kmh, "5")
  const btAplicar = document.createElement("button")
  btAplicar.type = "submit"
  btAplicar.textContent = t.apply
  form.append(rotulo, instante, kmh, btAplicar)
  const lista = document.createElement("ul")
  lista.setAttribute("data-rotas-editor-lista", "")
  const btRodar = botao(t.run, () => aplicar())
  btRodar.setAttribute("data-rotas-editor-rodar", "")
  const btRestaurar = botao(t.reset, () => { cenario = structuredClone(original); renderLista(); aplicar() })
  btRestaurar.setAttribute("data-rotas-editor-restaurar", "")
  const erroEditor = document.createElement("p")
  erroEditor.className = "rotas-erro"
  erroEditor.setAttribute("data-rotas-editor-erro", "")
  caixa.append(dica, form, lista, btRodar, btRestaurar, erroEditor)
  painel.after(caixa)

  canvas.addEventListener("click", (evento) => {
    const r = canvas.getBoundingClientRect()
    const aresta = arestaMaisProxima(cenario, evento.clientX - r.left, evento.clientY - r.top, r.width, r.height)
    if (!aresta) return
    selecionada = aresta
    rotulo.textContent = `${aresta.de} → ${aresta.para}`
    form.hidden = false
    instante.querySelector("input").focus()
  })

  form.addEventListener("submit", (evento) => {
    evento.preventDefault()
    const tI = Number(instante.querySelector("input").value)
    const v = Number(kmh.querySelector("input").value)
    if (!selecionada || !(tI >= 0) || !(v > 0)) { erroEditor.textContent = `${t.instant} ≥ 0, ${t.kmh} > 0`; return }
    erroEditor.textContent = ""
    cenario.atualizacoes = cenario.atualizacoes.filter((u) => !(u.de === selecionada.de && u.para === selecionada.para && u.t === tI))
    cenario.atualizacoes.push({ t: tI, de: selecionada.de, para: selecionada.para, kmh: v })
    cenario.atualizacoes.sort((a, b) => a.t - b.t)
    form.hidden = true
    renderLista()
  })

  function renderLista() {
    lista.replaceChildren(...cenario.atualizacoes.map((u, i) => {
      const li = document.createElement("li")
      li.textContent = `t=${u.t}s: ${u.de} → ${u.para} @ ${u.kmh} km/h `
      li.append(botao(t.remove, () => { cenario.atualizacoes.splice(i, 1); renderLista() }))
      return li
    }))
  }

  function aplicar() {
    raiz.__rotas.definirCenario(structuredClone(cenario))
    raiz.__rotas.rodar()
  }

  renderLista()
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
  let quadroPendente = 0

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
    if (canvas.width !== Math.round(largura * dpr) || canvas.height !== Math.round(altura * dpr)) {
      canvas.width = Math.round(largura * dpr)
      canvas.height = Math.round(altura * dpr)
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
    quadroPendente = requestAnimationFrame(laco)
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
      else { aviso.textContent = t.failed; aviso.hidden = false }
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
    quadroPendente = requestAnimationFrame(laco)
  }

  async function passo() {
    if (carregando) return
    if (!(await garantirTrace())) return
    pausar()
    avancar()
  }

  function pausar() {
    rodando = false
    cancelAnimationFrame(quadroPendente)
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
    const todos = analisar(trace)
    eventos = eventosVisiveis(todos)
    estados = [estadoInicial(todos)]
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
  new MutationObserver(() => quadro()).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] })
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => quadro())

  carregarCenarios(base)
    .then((cenarios) => {
      if (!cenarios[id]) throw new Error(`cenario ${id} nao existe`)
      definirCenario(structuredClone(cenarios[id]))
      if (raiz.hasAttribute("data-rotas-editor")) montarEditor(raiz, canvas, painel, t)
    })
    .catch((motivo) => {
      console.error("[rotas]", motivo)
      raiz.setAttribute("data-rotas-estado", "erro")
      if (erro) erro.hidden = false
      else { aviso.textContent = t.failed; aviso.hidden = false }
    })
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-rotas]").forEach(montar)
})
