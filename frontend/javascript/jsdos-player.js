// Carrega o emulador js-dos sob demanda. Nada e baixado ate o visitante
// clicar: sao cerca de 2,1 MB, e quem so veio ler sobre o projeto nao paga
// essa conta.

import { montarTeclado } from "./jsdos-keypad.js"

const SCRIPT = "/vendor/js-dos/js-dos.js"

// O js-dos.css nao e carregado. Ele abre com o Preflight do Tailwind e com a
// base do daisyUI, e como este arquivo o anexava ao <head> no clique — depois
// da nossa folha e com a mesma especificidade — um clique em Jogar achatava
// todo titulo do site e tirava cor e sublinhado de todo link. As poucas regras
// que a arvore do modo kiosk usa vivem em frontend/styles/crt.css, escopadas
// em .demo-screen.

// Repete o valor de data-path-prefix (Task 3) como fallback hardcoded. O
// js-dos.Dos() aponta por padrao para a CDN dele; se o atributo do DOM vier
// ausente ou vazio por qualquer motivo, este valor evita que a chamada caia
// de volta na CDN de terceiro em vez de falhar visivelmente.
const CAMINHO_PADRAO_DO_EMULADOR = "/vendor/js-dos/emulators/"

let carregamento = null

function carregarUmaVez() {
  if (carregamento) return carregamento

  carregamento = new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = SCRIPT
    script.onload = resolve
    script.onerror = () => reject(new Error("nao foi possivel carregar o js-dos"))
    document.head.appendChild(script)
  })

  return carregamento
}

// O window.Dos() volta na hora: o try/catch abaixo so cobre a falha de
// carregar o script. Bundle que da 404, WebAssembly que nao instancia, arquivo
// faltando no pathPrefix — tudo isso cai no estado de erro interno do js-dos,
// que nao emite evento nenhum (o onEvent dele so dispara emu-ready, ci-ready e
// fullscreen-change) e desenha, no maximo, um texto sem estilo dentro da
// moldura. Sem este relogio o visitante ficaria olhando um retangulo preto,
// que e exatamente o que a spec proibe. 30 s e folgado ate para 3G.
const LIMITE_DE_BOOT_MS = 30000

export async function bootJsdos(root) {
  const moldura = root.querySelector("[data-jsdos-frame]")
  const tela = root.querySelector("[data-jsdos-screen]")
  const erro = root.querySelector("[data-jsdos-error]")

  // Sem isto, um partial reorganizado faria o proprio catch estourar em cima
  // do erro original.
  if (!moldura || !tela || !erro) return

  let relogio = null

  function cancelarRelogio() {
    if (relogio === null) return
    clearTimeout(relogio)
    relogio = null
  }

  function mostrarFalha(motivo) {
    cancelarRelogio()
    moldura.hidden = true
    tela.hidden = true
    erro.hidden = false
    console.error("[jsdos]", motivo)
  }

  try {
    await carregarUmaVez()

    moldura.hidden = true
    tela.hidden = false

    relogio = setTimeout(() => {
      relogio = null
      mostrarFalha(new Error("o emulador nao ficou pronto em 30 s"))
    }, LIMITE_DE_BOOT_MS)

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
          cancelarRelogio()
          // Se o emulador chegou depois do limite, desfaz a mensagem de erro:
          // o jogo esta rodando, e ele que o visitante tem que ver.
          erro.hidden = true
          tela.hidden = false
          root.__ci = ci
          montarTeclado(root, ci)
          root.dispatchEvent(new CustomEvent("jsdos:ready"))
        }
      },
    })
  } catch (falha) {
    mostrarFalha(falha)
  }
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-jsdos]").forEach((root) => {
    const botao = root.querySelector("[data-jsdos-start]")
    if (!botao) return

    // O botao vem `disabled` do HTML: sem JavaScript ele nao faz nada, e
    // oferecer um botao morto e pior do que nao oferecer nenhum. Quem liga e
    // quem sabe atender o clique.
    botao.disabled = false
    botao.addEventListener("click", () => bootJsdos(root), { once: true })
  })
})
