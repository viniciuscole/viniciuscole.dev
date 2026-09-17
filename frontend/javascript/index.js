import "$styles/index.css"
import "$styles/syntax-highlighting.css"
import "./jsdos-player.js"
import "./wasm-player.js"

// Import all JavaScript & CSS files from src/_components
import components from "$components/**/*.{js,jsx,js.rb,css}"

const STORAGE_KEY = "theme"

// O tema salvo ja foi aplicado antes do primeiro paint pelo script inline de
// src/_partials/_head.erb. Aqui so tratamos o clique.
//
// Persistir e consequencia do clique, nunca do carregamento: gravar no load
// congelaria para sempre o `prefers-color-scheme` do primeiro acesso, e quem
// trocasse o tema do sistema depois ficaria preso ao antigo.
function activeTheme() {
  const chosen = document.documentElement.getAttribute("data-theme")
  if (chosen) return chosen
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
}

// As duas <meta name="theme-color"> de _head.erb seguem o prefers-color-scheme.
// Depois de um clique nenhuma das duas descreve mais a pagina, entao trocamos
// as duas por uma sem media, que vale sempre.
//
// A cor sai do --bg ja computado em vez de uma tabela aqui: os tokens continuam
// sendo a fonte unica, e mudar o papel no CSS nao exige lembrar deste arquivo.
function syncThemeColor() {
  const cor = getComputedStyle(document.documentElement)
    .getPropertyValue("--bg")
    .trim()
  if (!cor) return

  document.querySelectorAll('meta[name="theme-color"]').forEach((m) => m.remove())
  const meta = document.createElement("meta")
  meta.setAttribute("name", "theme-color")
  meta.setAttribute("content", cor)
  document.head.appendChild(meta)
}

const TRANSITION_MS = 300 + 50
let transitionTimer = 0

function animateThemeChange() {
  const html = document.documentElement
  html.classList.add("theme-transition")
  clearTimeout(transitionTimer)
  transitionTimer = setTimeout(() => {
    html.classList.remove("theme-transition")
  }, TRANSITION_MS)
}

document.addEventListener("DOMContentLoaded", () => {
  const button = document.querySelector(".theme-toggle")
  if (!button) return

  button.addEventListener("click", () => {
    const next = activeTheme() === "dark" ? "light" : "dark"
    animateThemeChange()
    document.documentElement.setAttribute("data-theme", next)
    syncThemeColor()
    try {
      localStorage.setItem(STORAGE_KEY, next)
    } catch (e) {
      // modo privativo/armazenamento bloqueado: o tema vale para esta pagina
    }
  })
})
