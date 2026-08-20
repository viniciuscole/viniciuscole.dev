// Traduz cliques em teclas para o emulador. O jogo so aceita comandos
// digitados, entao sem isso a demo e injogavel no celular.
//
// Os codigos sao as constantes KBD_* do js-dos (conferidas em
// node_modules/js-dos/dist/js-dos.js.map: KBD_1 = 49, KBD_x = 88, KBD_c = 67,
// KBD_s = 83, KBD_enter = 257, KBD_leftshift = 340): letras e digitos usam o
// valor ASCII maiusculo, teclas especiais usam codigos proprios acima de 256.

const TECLAS = {
  X: 88,
  C: 67,
  S: 83,
  1: 49,
  2: 50,
  3: 51,
  enter: 257,
  shift: 340,
}

// Uma tecla por chamada, com folga entre elas. O ci.simulateKeyPress(a, b, c)
// pressiona TODOS os argumentos no mesmo timestamp e solta ~16 ms depois, e o
// addKey interno so emite quando o estado da tecla muda (emulators.js:
// addKey(e,t,n){ !0===this.keyMatrix[e]!==t && ... sendClientMessage ... }).
// O segundo `1` de X11 encontrava a tecla ja pressionada e era engolido: a
// diagonal principal — 11, 22, 33, inclusive o C22 do painel — ficava
// injogavel.
const INTERVALO_MS = 40

// Marca escolhida no teclado. O jogo alterna os jogadores sozinho, mas o
// comando precisa dizer qual simbolo esta sendo jogado.
let marcaAtual = "X"

// Uma sequencia por vez: dois cliques rapidos intercalariam os digitos de dois
// comandos e o parser do jogo receberia lixo.
let enviando = false

function esperar(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

async function digitar(ci, codigos) {
  for (const codigo of codigos) {
    ci.simulateKeyPress(codigo)
    await esperar(INTERVALO_MS)
  }
}

// O jogo distingue caixa. O VCA.EXE compara o primeiro caractere digitado com
// 'X' (0x58) e 'C' (0x43) MAIUSCULOS para jogar, e com 'c' (0x63) e 's' (0x73)
// minusculos para reiniciar e sair — sao quatro comparacoes seguidas no
// executavel, sem nenhuma normalizacao de caixa. E um codigo de tecla nao
// carrega caixa: sem shift, KBD_c produz 'c', ou seja, "jogar circulo"
// reiniciaria a partida. O proprio teclado virtual do js-dos resolve assim,
// mandando KBD_leftshift junto do caractere.
async function digitarMaiuscula(ci, codigo) {
  ci.sendKeyEvent(TECLAS.shift, true)
  await esperar(INTERVALO_MS)
  ci.simulateKeyPress(codigo)
  await esperar(INTERVALO_MS)
  ci.sendKeyEvent(TECLAS.shift, false)
  await esperar(INTERVALO_MS)
}

async function emSequencia(tarefa) {
  if (enviando) return
  enviando = true
  try {
    await tarefa()
  } finally {
    enviando = false
  }
}

export function montarTeclado(root, ci) {
  const teclado = root.querySelector("[data-jsdos-keypad]")
  if (!teclado || !ci) return

  // Um segundo ci-ready religaria todos os botoes, e cada clique passaria a
  // mandar o comando duas vezes.
  if (teclado.dataset.montado === "sim") return
  teclado.dataset.montado = "sim"

  teclado.hidden = false

  teclado.querySelectorAll("[data-mark]").forEach((botao) => {
    botao.addEventListener("click", () => {
      marcaAtual = botao.dataset.mark
      teclado.querySelectorAll("[data-mark]").forEach((outro) => {
        outro.setAttribute("aria-pressed", String(outro === botao))
      })
    })
  })

  teclado.querySelectorAll("[data-cell]").forEach((botao) => {
    botao.addEventListener("click", () => {
      const [linha, coluna] = botao.dataset.cell.split("")
      emSequencia(async () => {
        await digitarMaiuscula(ci, TECLAS[marcaAtual])
        await digitar(ci, [TECLAS[linha], TECLAS[coluna], TECLAS.enter])
      })
    })
  })

  teclado.querySelectorAll("[data-action]").forEach((botao) => {
    botao.addEventListener("click", () => {
      // 'c' reinicia e 's' sai, e o jogo compara as duas em MINUSCULO: estas
      // nao levam shift, ao contrario da marca da jogada.
      const tecla = botao.dataset.action === "restart" ? TECLAS.C : TECLAS.S
      emSequencia(() => digitar(ci, [tecla, TECLAS.enter]))
    })
  })
}
