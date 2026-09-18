const MARGEM = 24
const RAIO_NO = 9
const RAIO_CARRO = 6
const TOLERANCIA_CLIQUE = 12

export function posicao(cenario, id, largura, altura) {
  const no = cenario.nos.find((n) => n.id === id)
  return { x: MARGEM + no.x * (largura - 2 * MARGEM), y: MARGEM + no.y * (altura - 2 * MARGEM) }
}

function espessura(kmh) {
  return Math.max(1, Math.min(6, kmh / 15))
}

function seta(ctx, a, b, cor) {
  const ang = Math.atan2(b.y - a.y, b.x - a.x)
  const px = b.x - Math.cos(ang) * (RAIO_NO + 2)
  const py = b.y - Math.sin(ang) * (RAIO_NO + 2)
  ctx.fillStyle = cor
  ctx.beginPath()
  ctx.moveTo(px, py)
  ctx.lineTo(px - Math.cos(ang - 0.5) * 8, py - Math.sin(ang - 0.5) * 8)
  ctx.lineTo(px - Math.cos(ang + 0.5) * 8, py - Math.sin(ang + 0.5) * 8)
  ctx.closePath()
  ctx.fill()
}

function linha(ctx, a, b, cor, grossura, tracejada) {
  ctx.strokeStyle = cor
  ctx.lineWidth = grossura
  ctx.setLineDash(tracejada ? [6, 6] : [])
  ctx.beginPath()
  ctx.moveTo(a.x, a.y)
  ctx.lineTo(b.x, b.y)
  ctx.stroke()
  ctx.setLineDash([])
}

function pares(caminho) {
  return caminho.slice(1).map((para, i) => [caminho[i], para])
}

const SEM_SOBREPOSICAO = { hover: null, selecionada: null, editadas: [] }

function mesmaAresta(a, b) {
  return Boolean(a && b && a.de === b.de && a.para === b.para)
}

function rotuloDaVia(ctx, a, b, texto, cor, fundo) {
  const x = a.x + (b.x - a.x) * 0.5
  const y = a.y + (b.y - a.y) * 0.5
  const ang = Math.atan2(b.y - a.y, b.x - a.x)
  const dx = -Math.sin(ang) * 11
  const dy = Math.cos(ang) * 11
  ctx.font = "11px ui-monospace, monospace"
  ctx.textAlign = "center"
  ctx.textBaseline = "middle"
  const larguraTexto = ctx.measureText(texto).width + 8
  ctx.fillStyle = fundo
  ctx.fillRect(x + dx - larguraTexto / 2, y + dy - 8, larguraTexto, 16)
  ctx.fillStyle = cor
  ctx.fillText(texto, x + dx, y + dy)
}

export function desenhar(ctx, cenario, estado, progresso, tema, largura, altura, sobreposicao = SEM_SOBREPOSICAO) {
  const p = (id) => posicao(cenario, id, largura, altura)
  ctx.clearRect(0, 0, largura, altura)

  for (const a of estado.arestas.values()) {
    const atualizada = estado.atualizada && estado.atualizada.de === a.de && estado.atualizada.para === a.para
    const relaxada = estado.relaxada && estado.relaxada.de === a.de && estado.relaxada.para === a.para
    const cor = atualizada || relaxada ? tema.accent : tema.border
    linha(ctx, p(a.de), p(a.para), cor, espessura(a.kmh), false)
    seta(ctx, p(a.de), p(a.para), cor)
  }

  for (const e of sobreposicao.editadas) linha(ctx, p(e.de), p(e.para), tema.accent, 1.5, true)
  if (sobreposicao.hover && !mesmaAresta(sobreposicao.hover, sobreposicao.selecionada)) {
    linha(ctx, p(sobreposicao.hover.de), p(sobreposicao.hover.para), tema.fg, 5, false)
  }
  if (sobreposicao.selecionada) {
    const sel = sobreposicao.selecionada
    linha(ctx, p(sel.de), p(sel.para), tema.accent, 6, false)
    seta(ctx, p(sel.de), p(sel.para), tema.accent)
  }

  for (const [de, para] of pares(estado.planejado)) linha(ctx, p(de), p(para), tema.accent, 2, true)
  for (const [de, para] of pares(estado.percorrido)) linha(ctx, p(de), p(para), tema.fg, 3, false)

  for (const e of sobreposicao.editadas) rotuloDaVia(ctx, p(e.de), p(e.para), `${e.kmh} km/h`, tema.accent, tema.bgSutil)

  ctx.font = "12px ui-monospace, monospace"
  ctx.textAlign = "center"
  ctx.textBaseline = "middle"
  for (const no of cenario.nos) {
    const { x, y } = p(no.id)
    const fechado = estado.fechados.has(no.id)
    const aberto = estado.abertos.has(no.id)
    ctx.beginPath()
    ctx.arc(x, y, RAIO_NO, 0, Math.PI * 2)
    ctx.fillStyle = fechado ? tema.muted : tema.bg
    ctx.fill()
    ctx.lineWidth = aberto ? 3 : 1.5
    ctx.strokeStyle = aberto ? tema.accent : tema.fg
    ctx.stroke()
    ctx.fillStyle = fechado ? tema.bg : tema.fg
    ctx.fillText(String(no.id), x, y)
    if (no.id === cenario.origem || no.id === cenario.destino) {
      ctx.fillStyle = tema.muted
      ctx.fillText(no.id === cenario.origem ? "A" : "B", x, y - RAIO_NO - 9)
    }
  }

  if (estado.carro) {
    const a = p(estado.carro.de)
    const b = p(estado.carro.para)
    const x = a.x + (b.x - a.x) * progresso
    const y = a.y + (b.y - a.y) * progresso
    ctx.beginPath()
    ctx.arc(x, y, RAIO_CARRO, 0, Math.PI * 2)
    ctx.fillStyle = tema.accent
    ctx.fill()
  }
}

export function arestaMaisProxima(cenario, x, y, largura, altura) {
  let melhor = null
  let menor = TOLERANCIA_CLIQUE
  for (const a of cenario.arestas) {
    const p1 = posicao(cenario, a.de, largura, altura)
    const p2 = posicao(cenario, a.para, largura, altura)
    const dx = p2.x - p1.x, dy = p2.y - p1.y
    const t = Math.max(0, Math.min(1, ((x - p1.x) * dx + (y - p1.y) * dy) / (dx * dx + dy * dy)))
    const d = Math.hypot(x - (p1.x + t * dx), y - (p1.y + t * dy))
    if (d < menor) { menor = d; melhor = { de: a.de, para: a.para } }
  }
  return melhor
}
