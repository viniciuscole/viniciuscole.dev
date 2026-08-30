// Carrega o jogo 2D compilado para WebAssembly, sob clique. Nada e baixado
// antes disso: sao ~380 KB entre .js, .wasm e .data.
const TEMPO_LIMITE = 30000

function iniciar(raiz) {
  // getAttribute, nao dataset.wasmBase: o nome do gancho aparece literal no
  // codigo, e o teste que cobra "todo gancho emitido e lido por alguem"
  // consegue enxerga-lo. Com dataset o nome vira camelCase e some.
  const base = raiz.getAttribute("data-wasm-base")
  const quadro = raiz.querySelector("[data-wasm-frame]")
  const botao = raiz.querySelector("[data-wasm-start]")
  const tela = raiz.querySelector("[data-wasm-screen]")
  const canvas = raiz.querySelector("[data-wasm-canvas]")
  const erro = raiz.querySelector("[data-wasm-error]")
  const fim = raiz.querySelector("[data-wasm-over]")
  const mensagem = raiz.querySelector("[data-wasm-over-message]")
  const dnovo = raiz.querySelector("[data-wasm-restart]")

  if (!base || !quadro || !botao || !tela || !canvas || !erro) return

  const textos = {
    won: raiz.dataset.textoVitoria,
    lost: raiz.dataset.textoDerrota,
  }

  botao.disabled = false

  botao.addEventListener("click", () => {
    botao.disabled = true
    quadro.hidden = true
    tela.hidden = false

    const limite = setTimeout(() => {
      tela.hidden = true
      erro.hidden = false
    }, TEMPO_LIMITE)

    // O botao direito pula. Sem isto o navegador abre o menu de contexto
    // em cima do jogo a cada pulo. Verificado: cancelar o contextmenu nao
    // impede o mousedown de chegar ao Emscripten.
    canvas.addEventListener("contextmenu", (evento) => evento.preventDefault())

    // O C++ chama isto a cada quadro enquanto o jogo esta acabado, entao
    // precisa ser idempotente.
    window.__jogo2d = {
      fim(venceu) {
        if (!fim || !fim.hidden) return
        mensagem.textContent = venceu ? textos.won : textos.lost
        fim.hidden = false
      },
    }

    const script = document.createElement("script")
    script.src = `${base}.js`
    script.onerror = () => {
      clearTimeout(limite)
      tela.hidden = true
      erro.hidden = false
    }
    script.onload = () => {
      window
        .criarJogo2D({
          canvas,
          // O main() do jogo le o caminho do SVG de argv[1]. No navegador
          // nao ha linha de comando; o Emscripten injeta os argumentos aqui.
          arguments: ["arena_teste.svg"],
        })
        .then((modulo) => {
          clearTimeout(limite)
          canvas.focus()

          if (dnovo) {
            dnovo.addEventListener("click", () => {
              modulo.ccall("reiniciarDoNavegador", null, [], [])
              fim.hidden = true
              canvas.focus()
            })
          }
        })
        .catch(() => {
          clearTimeout(limite)
          tela.hidden = true
          erro.hidden = false
        })
    }
    document.head.appendChild(script)
  })
}

document.querySelectorAll("[data-wasm]").forEach(iniciar)
