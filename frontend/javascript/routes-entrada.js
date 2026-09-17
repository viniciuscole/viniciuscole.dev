export function chaveAresta(de, para) {
  return `${de}-${para}`
}

export function gerarEntrada(cenario) {
  const linhas = [
    `${cenario.nos.length};${cenario.arestas.length}`,
    `${cenario.origem};${cenario.destino}`,
    `${cenario.kmh}`,
    ...cenario.arestas.map((a) => `${a.de};${a.para};${a.m}`),
    ...[...cenario.atualizacoes].sort((a, b) => a.t - b.t).map((u) => `${u.t};${u.de};${u.para};${u.kmh}`),
  ]
  return linhas.join("\n") + "\n"
}
