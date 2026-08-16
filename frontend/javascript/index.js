import "$styles/index.css"
import "$styles/syntax-highlighting.css"

// Import all JavaScript & CSS files from src/_components
import components from "$components/**/*.{js,jsx,js.rb,css}"

const STORAGE_KEY = "theme"

function applyTheme(theme) {
  document.documentElement.setAttribute("data-theme", theme)
  localStorage.setItem(STORAGE_KEY, theme)
}

function currentTheme() {
  const stored = localStorage.getItem(STORAGE_KEY)
  if (stored) return stored
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
}

document.addEventListener("DOMContentLoaded", () => {
  const button = document.querySelector(".theme-toggle")
  if (!button) return

  applyTheme(currentTheme())

  button.addEventListener("click", () => {
    applyTheme(currentTheme() === "dark" ? "light" : "dark")
  })
})
