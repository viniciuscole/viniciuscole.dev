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

function montarEditor(raiz, canvas, mapa, painel, t) {
  const original = structuredClone(raiz.__rotas.cenarioAtual())
  let cenario = structuredClone(original)
  let selecionada = null

  const cartao = document.createElement("form")
  cartao.className = "rotas-cartao"
  cartao.setAttribute("data-rotas-editor-form", "")
  cartao.hidden = true
  const titulo = document.createElement("p")
  titulo.className = "rotas-cartao-titulo"
  const via = document.createElement("strong")
  const meta = document.createElement("span")
  titulo.append(via, meta)
  const campo = (nome, texto, unidade) => {
    const label = document.createElement("label")
    const nomeSpan = document.createElement("span")
    nomeSpan.textContent = texto
    const grupo = document.createElement("span")
    grupo.className = "rotas-campo"
    const input = document.createElement("input")
    input.name = nome
    input.type = "number"
    input.min = nome === "kmh" ? "1" : "0"
    input.step = "1"
    input.required = true
    input.inputMode = "numeric"
    const un = document.createElement("span")
    un.textContent = unidade
    grupo.append(input, un)
    label.append(nomeSpan, grupo)
    return { label, input }
  }
  const instante = campo("instante", t.instant, "s")
  const kmh = campo("kmh", t.kmh, "km/h")
  const erroEditor = document.createElement("p")
  erroEditor.className = "rotas-cartao-erro"
  erroEditor.setAttribute("data-rotas-editor-erro", "")
  erroEditor.hidden = true
  const acoes = document.createElement("div")
  acoes.className = "rotas-cartao-acoes"
  const btAplicar = document.createElement("button")
  btAplicar.type = "submit"
  btAplicar.className = "rotas-primario"
  btAplicar.textContent = t.apply
  const btCancelar = botao(t.cancel, () => fechar())
  btCancelar.setAttribute("data-rotas-editor-cancelar", "")
  acoes.append(btAplicar, btCancelar)
  cartao.append(titulo, instante.label, kmh.label, erroEditor, acoes)
  mapa.append(cartao)

  const mudancas = document.createElement("section")
  mudancas.className = "rotas-mudancas"
  const cabecalho = document.createElement("div")
  cabecalho.className = "rotas-mudancas-cabecalho"
  const tituloMudancas = document.createElement("p")
  tituloMudancas.textContent = t.changes
  const btRestaurar = botao(t.reset, () => { cenario = structuredClone(original); fechar(); aplicar() })
  btRestaurar.className = "rotas-texto"
  btRestaurar.setAttribute("data-rotas-editor-restaurar", "")
  cabecalho.append(tituloMudancas, btRestaurar)
  const lista = document.createElement("ul")
  lista.setAttribute("data-rotas-editor-lista", "")
  const dica = document.createElement("p")
  dica.className = "rotas-dica"
  dica.textContent = t.editor_hint
  mudancas.append(cabecalho, lista, dica)
  painel.after(mudancas)

  const arestaEm = (evento) => {
    const r = canvas.getBoundingClientRect()
    return arestaMaisProxima(cenario, evento.clientX - r.left, evento.clientY - r.top, r.width, r.height)
  }
  const dadosDa = (aresta) => cenario.arestas.find((a) => a.de === aresta.de && a.para === aresta.para)
  const velocidadeAtual = (aresta) => {
    const edicoes = cenario.atualizacoes.filter((u) => u.de === aresta.de && u.para === aresta.para)
    return edicoes.length ? edicoes[edicoes.length - 1].kmh : cenario.kmh
  }

  let hoverAtual = null
  canvas.addEventListener("mousemove", (evento) => {
    const aresta = arestaEm(evento)
    const chave = aresta ? `${aresta.de}-${aresta.para}` : null
    if (chave === hoverAtual) return
    hoverAtual = chave
    canvas.style.cursor = aresta ? "pointer" : ""
    raiz.__rotas.definirSobreposicao({ hover: aresta })
  })
  canvas.addEventListener("mouseleave", () => { hoverAtual = null; raiz.__rotas.definirSobreposicao({ hover: null }) })

  canvas.addEventListener("click", (evento) => {
    const aresta = arestaEm(evento)
    if (!aresta) { fechar(); return }
    abrir(aresta, evento)
  })

  function abrir(aresta, evento) {
    selecionada = aresta
    const dados = dadosDa(aresta)
    via.textContent = `${t.road} ${aresta.de} → ${aresta.para}`
    meta.textContent = `${dados.m} m · ${t.now} ${velocidadeAtual(aresta)} km/h`
    instante.input.value = String(Math.round(raiz.__rotas.relogioAtual()))
    kmh.input.value = String(velocidadeAtual(aresta))
    erroEditor.hidden = true
    cartao.hidden = false
    posicionar(evento)
    raiz.__rotas.definirSobreposicao({ selecionada: aresta })
    kmh.input.focus()
    kmh.input.select()
  }

  function posicionar(evento) {
    const r = mapa.getBoundingClientRect()
    if (r.width < 640) { cartao.style.left = ""; cartao.style.top = ""; return }
    const x = evento.clientX - r.left
    const y = evento.clientY - r.top
    const largura = cartao.offsetWidth
    const altura = cartao.offsetHeight
    const esquerda = x + 16 + largura > r.width ? x - 16 - largura : x + 16
    const topo = Math.min(Math.max(8, y - altura / 2), r.height - altura - 8)
    cartao.style.left = `${Math.max(8, esquerda)}px`
    cartao.style.top = `${topo}px`
  }

  function fechar() {
    if (cartao.hidden) return
    cartao.hidden = true
    selecionada = null
    raiz.__rotas.definirSobreposicao({ selecionada: null })
  }

  document.addEventListener("keydown", (evento) => { if (evento.key === "Escape") fechar() })
  document.addEventListener("pointerdown", (evento) => {
    if (cartao.hidden || cartao.contains(evento.target) || evento.target === canvas) return
    fechar()
  })

  cartao.addEventListener("submit", (evento) => {
    evento.preventDefault()
    const tI = Number(instante.input.value)
    const v = Number(kmh.input.value)
    if (!selecionada || instante.input.value === "" || !(tI >= 0) || !(v > 0)) {
      erroEditor.textContent = t.invalid
      erroEditor.hidden = false
      return
    }
    cenario.atualizacoes = cenario.atualizacoes.filter((u) => !(u.de === selecionada.de && u.para === selecionada.para && u.t === tI))
    cenario.atualizacoes.push({ t: tI, de: selecionada.de, para: selecionada.para, kmh: v })
    cenario.atualizacoes.sort((a, b) => a.t - b.t)
    fechar()
    aplicar()
  })

  function renderLista() {
    const chave = (u) => `${u.t}-${u.de}-${u.para}-${u.kmh}`
    const originais = new Set(original.atualizacoes.map(chave))
    lista.replaceChildren(...cenario.atualizacoes.map((u, i) => {
      const li = document.createElement("li")
      if (originais.has(chave(u))) li.className = "rotas-original"
      const texto = document.createElement("span")
      texto.textContent = `t=${u.t} s · ${u.de} → ${u.para} · ${u.kmh} km/h`
      const btRemover = botao("×", () => { cenario.atualizacoes.splice(i, 1); aplicar() })
      btRemover.className = "rotas-texto"
      btRemover.setAttribute("aria-label", t.remove)
      btRemover.title = t.remove
      li.append(texto, btRemover)
      return li
    }))
    const mudou = JSON.stringify(cenario.atualizacoes) !== JSON.stringify(original.atualizacoes)
    btRestaurar.hidden = !mudou
    dica.hidden = mudou
    raiz.__rotas.definirSobreposicao({ editadas: cenario.atualizacoes.map((u) => ({ de: u.de, para: u.para, kmh: u.kmh })) })
  }

  function aplicar() {
    renderLista()
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
  const mapa = document.createElement("div")
  mapa.className = "rotas-mapa"
  canvas.replaceWith(mapa)
  mapa.append(canvas)
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
  btRodar.setAttribute("data-rotas-rodar", "")
  btRodar.disabled = true
  const btPasso = botao(t.step, () => passo())
  const btVelocidade = botao(`${t.speed} 1×`, () => { escala = escala === 1 ? 4 : 1; btVelocidade.textContent = `${t.speed} ${escala}×` })
  const btReiniciar = botao(t.restart, () => reiniciar())
  controles.replaceChildren(btRodar, btPasso, btVelocidade, btReiniciar)

  const relogioMostrador = document.createElement("output")
  relogioMostrador.className = "rotas-relogio"
  relogioMostrador.setAttribute("aria-label", t.clock)
  relogioMostrador.textContent = "00:00"
  mapa.append(relogioMostrador)

  const dl = document.createElement("dl")
  const ddFila = document.createElement("dd")
  ddFila.className = "rotas-fila"
  const ddChegada = document.createElement("dd")
  const dtChegada = document.createElement("dt")
  for (const [rotulo, dt, dd] of [[t.queue, document.createElement("dt"), ddFila], [t.arrival, dtChegada, ddChegada]]) {
    dt.textContent = rotulo
    dl.append(dt, dd)
  }
  const legenda = document.createElement("p")
  legenda.className = "rotas-legenda"
  for (const [classe, texto] of [["aberto", t.legend_open], ["fechado", t.legend_closed], ["planejado", t.legend_planned], ["percorrido", t.legend_driven], ["alterada", t.legend_edited]]) {
    const span = document.createElement("span")
    span.className = classe
    const amostra = document.createElement("i")
    span.append(amostra, texto)
    legenda.append(span)
  }
  controles.after(legenda)
  painel.replaceChildren(dl)
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

  let sobreposicao = { hover: null, selecionada: null, editadas: [] }
  let relogioAtual = 0

  function quadro() {
    if (!cenario) return
    const { largura, altura } = tamanho()
    const e = eventos[indice]
    const dur = e ? duracaoMs(e, escala) : 0
    const progresso = e && e.tipo === "move" && dur > 0 ? Math.min(1, decorrido / dur) : 1
    const s = estadoAtual()
    const visivel = e && e.tipo === "move" ? { ...s, carro: { de: e.de, para: e.para, t0: e.t0, t1: e.t1 } } : s
    desenhar(ctx, cenario, visivel, progresso, tema(), largura, altura, sobreposicao)
    const relogio = e && e.tipo === "move" ? e.t0 + (e.t1 - e.t0) * progresso : s.relogio
    relogioAtual = relogio
    relogioMostrador.textContent = relogioTexto(relogio)
    raiz.setAttribute("data-rotas-relogio", String(Math.round(relogio)))
    ddFila.replaceChildren(...[...s.abertos].sort((a, b) => a[1] - b[1]).map(([no, tempo]) => {
      const span = document.createElement("span")
      span.textContent = `${no}: ${relogioTexto(s.base + tempo)}`
      return span
    }))
    ddChegada.textContent = s.fim ? `${s.fim.km.toFixed(1)} km ${t.in_time} ${relogioTexto(s.fim.t)}` : ""
    dtChegada.hidden = ddChegada.hidden = !s.fim
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

  raiz.__rotas = {
    rodar, pausar, passo, reiniciar, definirCenario,
    cenarioAtual: () => cenario,
    relogioAtual: () => relogioAtual,
    definirSobreposicao: (nova) => { sobreposicao = { ...sobreposicao, ...nova }; quadro() },
  }
  window.addEventListener("resize", quadro)
  new MutationObserver(() => quadro()).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] })
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => quadro())

  carregarCenarios(base)
    .then((cenarios) => {
      if (!cenarios[id]) throw new Error(`cenario ${id} nao existe`)
      definirCenario(structuredClone(cenarios[id]))
      if (raiz.hasAttribute("data-rotas-editor")) montarEditor(raiz, canvas, mapa, painel, t)
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
