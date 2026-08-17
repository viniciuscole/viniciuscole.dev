import "$styles/index.css"
import "$styles/syntax-highlighting.css"

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

document.addEventListener("DOMContentLoaded", () => {
  const button = document.querySelector(".theme-toggle")
  if (!button) return

  button.addEventListener("click", () => {
    const next = activeTheme() === "dark" ? "light" : "dark"
    document.documentElement.setAttribute("data-theme", next)
    try {
      localStorage.setItem(STORAGE_KEY, next)
    } catch (e) {
      // modo privativo/armazenamento bloqueado: o tema vale para esta pagina
    }
  })
})
