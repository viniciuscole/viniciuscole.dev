const { chromium } = require("playwright")

const ALVO = process.env.ALVO
if (!ALVO) {
  console.error("defina ALVO com a URL da pagina")
  process.exit(2)
}

const falhas = []
function confere(descricao, condicao) {
  console.log(`${condicao ? "ok  " : "FALHA"} ${descricao}`)
  if (!condicao) falhas.push(descricao)
}

;(async () => {
  const browser = await chromium.launch()
  const page = await browser.newPage()
  const erros = []
  page.on("pageerror", (e) => erros.push(String(e)))
  page.on("console", (m) => { if (m.type() === "error") erros.push(m.text()) })

  await page.goto(ALVO, { waitUntil: "networkidle" })
  const principal = page.locator("[data-rotas-editor]")
  await principal.waitFor()
  confere("player principal pronto", (await principal.getAttribute("data-rotas-estado")) === "pronto")
  confere("quatro players inline + principal", (await page.locator("[data-rotas]").count()) === 5)

  await principal.locator("button").first().click()
  await page.locator("[data-rotas-editor][data-rotas-estado='fim']").waitFor({ timeout: 120000 })
  confere("caminho final desvia por 5", (await principal.getAttribute("data-rotas-caminho")) === "1 2 5 6")
  confere("relogio termina em 240 s", (await principal.getAttribute("data-rotas-relogio")) === "240")

  const png = (await principal.locator("canvas").screenshot()).toString("base64")
  const pintado = await page.evaluate(async (b64) => {
    const img = new Image()
    img.src = "data:image/png;base64," + b64
    await img.decode()
    const c = document.createElement("canvas")
    c.width = img.width; c.height = img.height
    const ctx = c.getContext("2d")
    ctx.drawImage(img, 0, 0)
    const d = ctx.getImageData(0, 0, c.width, c.height).data
    const cores = new Set()
    for (let i = 0; i < d.length; i += 4 * 97) cores.add(`${d[i]},${d[i + 1]},${d[i + 2]}`)
    return cores.size
  }, png)
  confere("o canvas tem mais de tres cores (algo foi desenhado)", pintado > 3)
  confere("sem erros de JS na pagina", erros.length === 0)
  if (erros.length) console.log(erros.join("\n"))

  await browser.close()
  if (falhas.length) process.exit(1)
})()
