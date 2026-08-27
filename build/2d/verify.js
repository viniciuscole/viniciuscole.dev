// Verificacao em navegador de verdade. Existe porque nenhum teste estatico
// pega uma regressao de runtime do OpenGL emulado: a primeira compilacao
// deste port linkou limpa e abortava no primeiro quadro.
//
// Alvo via env ALVO. Roda dentro da imagem do Playwright (ver rake
// demo2d:verify), nunca no host.
const { chromium } = require("playwright")

const ALVO = process.env.ALVO
if (!ALVO) {
  console.error("defina ALVO com a URL a verificar")
  process.exit(2)
}

const falhas = []
function confere(descricao, condicao) {
  console.log(`${condicao ? "ok  " : "FALHA"} ${descricao}`)
  if (!condicao) falhas.push(descricao)
}

// Mede a altura do heroi achando o pixel verde mais alto do quadro.
// Ler o canvas WebGL direto devolve preto (o drawing buffer nao e
// preservado apos a composicao), entao o caminho correto e
// screenshot -> <img> -> canvas 2D -> getImageData. Menor y = mais alto.
async function alturaDoHeroi(page) {
  const png = (await page.locator("#canvas").screenshot()).toString("base64")
  return page.evaluate(async (b64) => {
    const img = new Image()
    img.src = "data:image/png;base64," + b64
    await img.decode()
    const c = document.createElement("canvas")
    c.width = img.width
    c.height = img.height
    const ctx = c.getContext("2d")
    ctx.drawImage(img, 0, 0)
    const d = ctx.getImageData(0, 0, c.width, c.height).data
    for (let y = 0; y < c.height; y++) {
      for (let x = 0; x < c.width; x++) {
        const i = (y * c.width + x) * 4
        if (d[i + 1] > 150 && d[i] < 100 && d[i + 2] < 100) return y
      }
    }
    return null
  }, png)
}

async function quadro(page) {
  const png = await page.locator("#canvas").screenshot()
  return png.toString("base64")
}

async function pixelsNaoPretos(page) {
  const png = (await page.locator("#canvas").screenshot()).toString("base64")
  return page.evaluate(async (b64) => {
    const img = new Image()
    img.src = "data:image/png;base64," + b64
    await img.decode()
    const c = document.createElement("canvas")
    c.width = img.width
    c.height = img.height
    c.getContext("2d").drawImage(img, 0, 0)
    const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data
    let n = 0
    for (let i = 0; i < d.length; i += 4) {
      if (d[i] || d[i + 1] || d[i + 2]) n++
    }
    return n
  }, png)
}

;(async () => {
  const browser = await chromium.launch({
    args: [
      "--use-gl=angle",
      "--use-angle=swiftshader",
      "--enable-unsafe-swiftshader",
      "--disable-gpu-sandbox",
    ],
  })
  const page = await browser.newPage({ viewport: { width: 900, height: 800 } })

  const erros = []
  page.on("pageerror", (e) => erros.push(e.message))

  await page.goto(ALVO, { waitUntil: "load" })
  await page.waitForSelector("#canvas", { timeout: 30000 })
  await page.waitForFunction(() => window.__modulo !== undefined, { timeout: 60000 })
  await page.waitForTimeout(2500)

  confere("o canvas desenha (pixels nao pretos)", (await pixelsNaoPretos(page)) > 1000)

  const caixa = await page.locator("#canvas").boundingBox()
  await page.mouse.move(caixa.x + caixa.width / 2, caixa.y + caixa.height / 2)
  await page.mouse.click(caixa.x + caixa.width / 2, caixa.y + caixa.height / 2)
  await page.waitForTimeout(400)

  const parado = await quadro(page)
  await page.keyboard.down("d")
  await page.waitForTimeout(1200)
  await page.keyboard.up("d")
  await page.waitForTimeout(300)
  confere("a tecla d muda o quadro", (await quadro(page)) !== parado)

  await page.keyboard.down("a")
  await page.waitForTimeout(600)
  await page.keyboard.up("a")
  await page.waitForTimeout(300)
  confere("a tecla a muda o quadro", (await quadro(page)) !== parado)

  const chao = await alturaDoHeroi(page)
  await page.mouse.down({ button: "right" })
  await page.waitForTimeout(900)
  const pico = await alturaDoHeroi(page)
  await page.mouse.up({ button: "right" })
  confere("o botao direito levanta o heroi", pico !== null && chao !== null && pico < chao)

  confere("nenhum erro de pagina", erros.length === 0)
  if (erros.length) console.error(erros.join("\n"))

  await browser.close()

  if (falhas.length) {
    console.error(`\n${falhas.length} verificacao(oes) falharam`)
    process.exit(1)
  }
  console.log("\ntudo verificado")
})()

module.exports = { alturaDoHeroi, quadro, pixelsNaoPretos, confere }
