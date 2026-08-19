// Carrega o emulador js-dos sob demanda. Nada e baixado ate o visitante
// clicar: sao cerca de 1,7 MB, e quem so veio ler sobre o projeto nao paga
// essa conta.

import { montarTeclado } from "./jsdos-keypad.js"

const SCRIPT = "/vendor/js-dos/js-dos.js"
const ESTILOS = "/vendor/js-dos/js-dos.css"

// Repete o valor de data-path-prefix (Task 3) como fallback hardcoded. O
// js-dos.Dos() aponta por padrao para a CDN dele; se o atributo do DOM vier
// ausente ou vazio por qualquer motivo, este valor evita que a chamada caia
// de volta na CDN de terceiro em vez de falhar visivelmente.
const CAMINHO_PADRAO_DO_EMULADOR = "/vendor/js-dos/emulators/"

let carregamento = null

function carregarUmaVez() {
  if (carregamento) return carregamento

  carregamento = new Promise((resolve, reject) => {
    const estilos = document.createElement("link")
    estilos.rel = "stylesheet"
    estilos.href = ESTILOS
    document.head.appendChild(estilos)

    const script = document.createElement("script")
    script.src = SCRIPT
    script.onload = resolve
    script.onerror = () => reject(new Error("nao foi possivel carregar o js-dos"))
    document.head.appendChild(script)
  })

  return carregamento
}

export async function bootJsdos(root) {
  const moldura = root.querySelector("[data-jsdos-frame]")
  const tela = root.querySelector("[data-jsdos-screen]")
  const erro = root.querySelector("[data-jsdos-error]")

  try {
    await carregarUmaVez()

    moldura.hidden = true
    tela.hidden = false

    window.Dos(tela, {
      url: root.dataset.bundle,
      // Obrigatorio: o padrao do js-dos aponta para a CDN dele, o que furaria
      // a regra de zero requisicoes a terceiros.
      pathPrefix: root.dataset.pathPrefix || CAMINHO_PADRAO_DO_EMULADOR,
      backend: "dosbox",
      // Esconde a interface propria do js-dos. Quem enquadra o jogo e o site.
      kiosk: true,
      imageRendering: "pixelated",
      autoStart: true,
      onEvent: (evento, ci) => {
        if (evento === "ci-ready") {
          root.__ci = ci
          montarTeclado(root, ci)
          root.dispatchEvent(new CustomEvent("jsdos:ready"))
        }
      },
    })
  } catch (falha) {
    moldura.hidden = true
    tela.hidden = true
    erro.hidden = false
    console.error("[jsdos]", falha)
  }
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-jsdos]").forEach((root) => {
    const botao = root.querySelector("[data-jsdos-start]")
    if (!botao) return

    botao.addEventListener("click", () => bootJsdos(root), { once: true })
  })
})
