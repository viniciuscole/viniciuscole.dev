export function criarSimulador({ carregarScript }) {
  let moduloPromessa = null
  let saida = []

  async function instanciar(base) {
    const criarRotas = await carregarScript(`${base}/rotas.js`)
    const opcoes = {
      print: (linha) => saida.push(linha),
      printErr: (linha) => console.warn("[rotas]", linha),
    }
    if (typeof window !== "undefined") opcoes.locateFile = (arquivo) => `${base}/${arquivo}`
    return criarRotas(opcoes)
  }

  return {
    async rodar(entrada, base = "/demos/car-routes") {
      if (!moduloPromessa) {
        moduloPromessa = instanciar(base).catch((motivo) => {
          moduloPromessa = null
          throw motivo
        })
      }
      const modulo = await moduloPromessa
      saida = []
      const codigo = modulo.ccall("run_trace", "number", ["string"], [entrada])
      if (codigo !== 0) throw new Error(`run_trace retornou ${codigo}`)
      return saida.join("\n") + "\n"
    },
  }
}

export function carregarScriptNoNavegador(url) {
  return new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = url
    script.onerror = () => reject(new Error(`nao foi possivel carregar ${url}`))
    script.onload = () => resolve(window.criarRotas)
    document.head.appendChild(script)
  })
}
