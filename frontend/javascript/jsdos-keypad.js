// Traduz cliques em teclas para o emulador. O jogo so aceita comandos
// digitados, entao sem isso a demo e injogavel no celular.
//
// Os codigos sao as constantes KBD_* do js-dos, extraidas do bundle dele:
// letras e digitos usam o valor ASCII maiusculo, teclas especiais usam
// codigos proprios acima de 256.

const TECLAS = {
  X: 88,
  C: 67,
  S: 83,
  1: 49,
  2: 50,
  3: 51,
  enter: 257,
}

// Marca escolhida no teclado. O jogo alterna os jogadores sozinho, mas o
// comando precisa dizer qual simbolo esta sendo jogado.
let marcaAtual = "X"

export function montarTeclado(root, ci) {
  const teclado = root.querySelector("[data-jsdos-keypad]")
  if (!teclado || !ci) return

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
      ci.simulateKeyPress(TECLAS[marcaAtual], TECLAS[linha], TECLAS[coluna])
      ci.simulateKeyPress(TECLAS.enter)
    })
  })

  teclado.querySelectorAll("[data-action]").forEach((botao) => {
    botao.addEventListener("click", () => {
      // 'c' reinicia e 's' sai; o jogo aceita as duas em minusculo, e o
      // emulador nao distingue caixa no codigo da tecla.
      const tecla = botao.dataset.action === "restart" ? TECLAS.C : TECLAS.S
      ci.simulateKeyPress(tecla)
      ci.simulateKeyPress(TECLAS.enter)
    })
  })
}
