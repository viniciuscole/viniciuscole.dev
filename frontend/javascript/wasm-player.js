// Carrega o jogo 2D compilado para WebAssembly, sob clique. Nada e baixado
// antes disso: sao ~380 KB entre .js, .wasm e .data.
const TEMPO_LIMITE = 30000

function iniciar(raiz) {
  // getAttribute, nao dataset.wasmBase: o nome do gancho aparece literal no
  // codigo, e o teste que cobra "todo gancho emitido e lido por alguem"
  // consegue enxerga-lo. Com dataset o nome vira camelCase e some.
  const base = raiz.getAttribute("data-wasm-base")
  // Diretorio do bundle, separado da pagina: o partial fica em /projects/...
  // e o bundle em /demos/..., diretorios diferentes mesmo em producao.
  const diretorio = base ? base.slice(0, base.lastIndexOf("/")) : ""
  const quadro = raiz.querySelector("[data-wasm-frame]")
  const botao = raiz.querySelector("[data-wasm-start]")
  const tela = raiz.querySelector("[data-wasm-screen]")
  const canvas = raiz.querySelector("[data-wasm-canvas]")
  const erro = raiz.querySelector("[data-wasm-error]")
  const fim = raiz.querySelector("[data-wasm-over]")
  const mensagem = raiz.querySelector("[data-wasm-over-message]")
  const dnovo = raiz.querySelector("[data-wasm-restart]")

  // mensagem entra na guarda porque fim() a desreferencia sem checar: so nao
  // quebra hoje porque o mesmo partial sempre emite os dois juntos.
  if (!base || !quadro || !botao || !tela || !canvas || !erro || !mensagem) return

  const textos = {
    won: raiz.dataset.textoVitoria,
    lost: raiz.dataset.textoDerrota,
  }

  botao.disabled = false

  // once: true espelha o jsdos-player.js: o botao ja se desabilita apos o
  // clique, mas depender so disso e implicito - o listener se protege
  // explicitamente, como o irmao faz.
  botao.addEventListener(
    "click",
    () => {
      botao.disabled = true
      quadro.hidden = true
      tela.hidden = false

      let limite = setTimeout(() => {
        limite = null
        mostrarFalha(new Error("o jogo nao carregou em 30 s"))
      }, TEMPO_LIMITE)

      function cancelarLimite() {
        if (limite === null) return
        clearTimeout(limite)
        limite = null
      }

      // Funcao central de falha: os tres caminhos (script que nao carrega,
      // tempo limite, factory que rejeita) convergem aqui, e ela loga -
      // sem isto o player falhava calado, dificultando depurar em producao.
      function mostrarFalha(motivo) {
        cancelarLimite()
        tela.hidden = true
        erro.hidden = false
        console.error("[wasm]", motivo)
      }

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
        // O C++ chama isto quando restartGame() zera o estado -- inclusive
        // pelo atalho de teclado R, que nao passa pelo botao "jogar de novo"
        // e portanto nunca escondia o overlay sozinho. Sem isto, apertar R
        // deixava um jogo vivo debaixo de uma tela escura com pointer-events
        // filtrando o mouse (.demo-over cobre o canvas inteiro).
        jogando() {
          if (fim) fim.hidden = true
        },
      }

      // O GLUT do Emscripten escuta keydown/keyup na window em captura e da
      // preventDefault em Tab, Enter e Espaco -- teclas que o jogo nao usa e a
      // pagina precisa. Sem isto, a partir do clique em Jogar o visitante que
      // navega por teclado fica preso no canvas: nao alcanca o rodape nem o
      // botao de tema, e nem o "jogar de novo" do proprio overlay. Registrado
      // ANTES de subir o modulo, este listener roda primeiro e as segura.
      const TECLAS_DA_PAGINA = new Set(["Tab", "Enter", " "])
      for (const tipo of ["keydown", "keyup"]) {
        window.addEventListener(
          tipo,
          (evento) => {
            if (TECLAS_DA_PAGINA.has(evento.key)) evento.stopImmediatePropagation()
          },
          true,
        )
      }

      const script = document.createElement("script")
      script.src = `${base}.js`
      script.onerror = () => mostrarFalha(new Error("nao foi possivel carregar o script do jogo"))
      script.onload = () => {
        window
          .criarJogo2D({
            canvas,
            // O main() do jogo le o caminho do SVG de argv[1]. No navegador
            // nao ha linha de comando; o Emscripten injeta os argumentos aqui.
            arguments: ["arena_teste.svg"],
            // O loader gerado pelo Emscripten resolve o .data e o .wasm pelo
            // caminho da PAGINA (window.location), nao pelo diretorio do
            // proprio jogo.js -- `_scriptName` so vem preenchido em Node e em
            // Worker, nao em uma <script> normal de pagina. Sem isto os dois
            // dao 404 sempre que a pagina e o bundle moram em diretorios
            // diferentes - que e sempre o nosso caso (pagina em
            // /projects/..., bundle em /demos/...).
            locateFile: (nome) => `${diretorio}/${nome}`,
          })
          .then((modulo) => {
            cancelarLimite()
            // Se o modulo terminou de subir depois do tempo limite, desfaz a
            // mensagem de erro: o jogo esta rodando, e ele que o visitante
            // tem que ver, nao uma tela de erro permanente e mentirosa.
            erro.hidden = true
            tela.hidden = false
            canvas.focus()

            if (dnovo) {
              dnovo.addEventListener("click", () => {
                modulo.ccall("reiniciarDoNavegador", null, [], [])
                fim.hidden = true
                canvas.focus()
              })
            }
          })
          .catch((motivo) => mostrarFalha(motivo))
      }
      document.head.appendChild(script)
    },
    { once: true },
  )
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-wasm]").forEach(iniciar)
})
