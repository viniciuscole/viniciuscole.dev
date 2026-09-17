import { chaveAresta } from "./routes-entrada.js"

const SEGUNDOS_SIMULADOS_POR_SEGUNDO = 60
const PASSO_MS = { pop: 250, relax: 250, replan: 400, plan: 600, update: 600, unreachable: 600, graph: 0, edge: 0, done: 0 }

export function analisar(texto) {
  return texto
    .split("\n")
    .filter((l) => l.trim() !== "")
    .map((linha) => {
      const [tipo, ...c] = linha.trim().split(/\s+/)
      const n = c.map(Number)
      switch (tipo) {
        case "graph": return { tipo, n: n[0], e: n[1] }
        case "edge": return { tipo, de: n[0], para: n[1], m: n[2], kmh: n[3] }
        case "replan": return { tipo, no: n[0], t: n[1] }
        case "pop": return { tipo, no: n[0], t: n[1] }
        case "relax": return { tipo, de: n[0], para: n[1], t: n[2] }
        case "plan": {
          const ultimo = c[c.length - 1]
          const eta = ultimo === "unreachable" ? null : Number(ultimo)
          return { tipo, caminho: n.slice(0, -1), eta }
        }
        case "move": return { tipo, de: n[0], para: n[1], t0: n[2], t1: n[3] }
        case "update": return { tipo, de: n[0], para: n[1], kmh: n[2], t: n[3] }
        case "unreachable": return { tipo, no: n[0], t: n[1] }
        case "done": return { tipo, t: n[0], km: n[1] }
        default: return { tipo: "ignorado", linha }
      }
    })
    .filter((e) => e.tipo !== "ignorado")
}

export function eventosVisiveis(eventos) {
  return eventos.filter((e) => e.tipo !== "graph" && e.tipo !== "edge")
}

export function estadoInicial(eventos) {
  const arestas = new Map()
  for (const e of eventos) {
    if (e.tipo === "edge") arestas.set(chaveAresta(e.de, e.para), { de: e.de, para: e.para, m: e.m, kmh: e.kmh })
  }
  return {
    arestas, relogio: 0, base: 0,
    fechados: new Set(), abertos: new Map(), relaxada: null,
    planejado: [], percorrido: [], carro: null, atualizada: null, fim: null, inalcancavel: false,
  }
}

export function reduzir(estado, e) {
  const s = {
    ...estado,
    arestas: new Map([...estado.arestas].map(([k, v]) => [k, { ...v }])),
    fechados: new Set(estado.fechados),
    abertos: new Map(estado.abertos),
    planejado: [...estado.planejado],
    percorrido: [...estado.percorrido],
    relaxada: null,
  }
  switch (e.tipo) {
    case "replan":
      s.base = e.t; s.fechados.clear(); s.abertos.clear(); s.planejado = []; s.carro = null; s.atualizada = null
      break
    case "pop":
      s.abertos.delete(e.no); s.fechados.add(e.no)
      break
    case "relax":
      s.abertos.set(e.para, e.t); s.relaxada = { de: e.de, para: e.para }
      break
    case "plan":
      s.planejado = e.caminho
      break
    case "move":
      if (s.percorrido.length === 0) s.percorrido.push(e.de)
      s.percorrido.push(e.para)
      s.carro = { de: e.de, para: e.para, t0: e.t0, t1: e.t1 }
      s.relogio = e.t1
      break
    case "update": {
      const a = s.arestas.get(chaveAresta(e.de, e.para))
      if (a) a.kmh = e.kmh
      s.atualizada = { de: e.de, para: e.para, t: e.t }
      s.relogio = e.t
      break
    }
    case "unreachable":
      s.inalcancavel = true
      break
    case "done":
      s.fim = { t: e.t, km: e.km }
      break
  }
  return s
}

export function duracaoMs(e, escala) {
  const base = e.tipo === "move" ? ((e.t1 - e.t0) / SEGUNDOS_SIMULADOS_POR_SEGUNDO) * 1000 : PASSO_MS[e.tipo] ?? 0
  return base / escala
}
