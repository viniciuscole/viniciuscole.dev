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

// Bancada e pagina do site usam seletores de canvas diferentes: a bancada
// serve um #canvas fixo, a pagina real usa [data-wasm-canvas]. Uma variavel
// de ambiente deixa o mesmo script servir aos dois alvos.
const CANVAS = process.env.CANVAS || "#canvas"

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
  const png = (await page.locator(CANVAS).screenshot()).toString("base64")
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

// Centroide horizontal dos pixels do heroi. Medir a posicao dele, e nao o
// quadro inteiro, e o que torna a afirmacao real: os sete oponentes da arena
// andam e atiram sozinhos (enemiesCanWalk e enemiesCanShoot nascem true no
// main.cpp), entao o quadro muda entre dois instantes quaisquer, com ou sem
// teclado. Comparar quadros passaria com a entrada desligada. O centroide e
// mais estavel que o pixel verde mais a esquerda porque as pernas do heroi
// se animam ao andar.
async function horizontalDoHeroi(page) {
  const png = (await page.locator(CANVAS).screenshot()).toString("base64")
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
    let soma = 0
    let n = 0
    for (let y = 0; y < c.height; y++) {
      for (let x = 0; x < c.width; x++) {
        const i = (y * c.width + x) * 4
        if (d[i + 1] > 150 && d[i] < 100 && d[i + 2] < 100) {
          soma += x
          n++
        }
      }
    }
    return n ? soma / n : null
  }, png)
}

async function pixelsNaoPretos(page) {
  const png = (await page.locator(CANVAS).screenshot()).toString("base64")
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

  // Na pagina do site a demo carrega sob clique; na bancada ela ja sobe
  // sozinha. Clicar se houver botao cobre os dois casos com um script so.
  const comecar = page.locator("[data-wasm-start]")
  const naPaginaDoSite = (await comecar.count()) > 0
  if (naPaginaDoSite) {
    await comecar.click()
    await page.waitForSelector("[data-wasm-canvas]", { state: "visible", timeout: 30000 })
  }

  await page.waitForSelector(CANVAS, { timeout: 30000 })
  // O canvas so ganha tamanho depois que o modulo sobe e o GLUT cria a
  // janela. Serve para a bancada e para a pagina do site: window.__modulo e
  // exclusivo da bancada, o player do site nao expoe o modulo de proposito.
  await page.waitForFunction(
    (sel) => {
      const c = document.querySelector(sel)
      return c && c.width > 0 && c.clientWidth > 0
    },
    CANVAS,
    { timeout: 60000 }
  )
  await page.waitForTimeout(2500)

  confere("o canvas desenha (pixels nao pretos)", (await pixelsNaoPretos(page)) > 1000)

  const caixa = await page.locator(CANVAS).boundingBox()
  await page.mouse.move(caixa.x + caixa.width / 2, caixa.y + caixa.height / 2)
  await page.mouse.click(caixa.x + caixa.width / 2, caixa.y + caixa.height / 2)
  await page.waitForTimeout(400)

  // Deslocamento horizontal medido cedo, perto do spawn: a camera acompanha
  // o heroi e, depois de andar bastante, ele tende a ficar centralizado na
  // tela e o deslocamento observado encolhe -- medir tarde tornaria a
  // afirmacao instavel.
  const xInicial = await horizontalDoHeroi(page)
  await page.keyboard.down("d")
  await page.waitForTimeout(1200)
  await page.keyboard.up("d")
  await page.waitForTimeout(300)
  const xAposD = await horizontalDoHeroi(page)
  confere(
    "a tecla d desloca o heroi para a direita",
    xInicial !== null && xAposD !== null && xAposD - xInicial > 20
  )

  await page.keyboard.down("a")
  await page.waitForTimeout(600)
  await page.keyboard.up("a")
  await page.waitForTimeout(300)
  const xAposA = await horizontalDoHeroi(page)
  confere(
    "a tecla a desloca o heroi para a esquerda",
    xAposA !== null && xAposD !== null && xAposA < xAposD
  )

  // ESC nao pode mais matar a demo. Medir so a posicao do heroi apos o ESC
  // nao bastaria: alturaDoHeroi/horizontalDoHeroi leem o que esta composto
  // na tela AGORA, nao algo que dependa do laco principal continuar
  // rodando de verdade. Duas checagens complementares abaixo, calibradas
  // forcando de proposito o guard a regredir (trocando #ifndef
  // __EMSCRIPTEN__ por #if 1 e reconstruindo) para confirmar que pegam o
  // defeito:
  //   - "ESC nao gera erro de pagina": e a que efetivamente falha quando o
  //     guard regride. Sob -sEXIT_RUNTIME=0 (ver build.sh), exit(0) nao
  //     interrompe o laco principal -- o requestAnimationFrame que o
  //     Emscripten ja registrou continua rodando de qualquer jeito. O que
  //     exit() faz de fato e lancar uma excecao ExitStatus nao capturada
  //     dentro do handler de tecla, que vira um "pageerror" no navegador.
  //   - "ESC nao encerra o jogo (ele ainda responde depois)": nao pegou o
  //     defeito sozinha no teste forcado (o laco seguiu rodando e o heroi
  //     seguiu andando mesmo com o exit(0) ativo, exatamente por causa do
  //     EXIT_RUNTIME=0 acima) -- mas fica como segunda linha de defesa
  //     caso o build mude para EXIT_RUNTIME=1 no futuro, cenario em que o
  //     laco realmente pararia e essa seria a checagem que pegaria.
  //
  // Medido aqui, logo apos os testes de a/d e perto do spawn, pelo mesmo
  // motivo do comentario acima deles: mais tarde na sequencia a camera ja
  // recentralizou o heroi depois de ele andar bastante, e o deslocamento
  // aparente por pixel encolhe.
  await page.waitForTimeout(2500)
  const errosAntesDoEsc = erros.length
  await page.keyboard.press("Escape")
  await page.waitForTimeout(500)

  confere("ESC nao gera erro de pagina", erros.length === errosAntesDoEsc)

  const antesDoAndar = await horizontalDoHeroi(page)
  await page.keyboard.down("d")
  await page.waitForTimeout(1000)
  await page.keyboard.up("d")
  await page.waitForTimeout(300)
  const depoisDoAndar = await horizontalDoHeroi(page)

  confere(
    "ESC nao encerra o jogo (ele ainda responde depois)",
    antesDoAndar !== null &&
      depoisDoAndar !== null &&
      depoisDoAndar > antesDoAndar + 20
  )

  // Devolve o heroi para perto de onde estava antes deste teste. Sem isso,
  // o deslocamento extra empurra o heroi contra um obstaculo mais adiante
  // na arena, o que trava o pulo dos testes seguintes (o heroi fica preso
  // "caindo" contra a parede em vez de tocar o chao). Andar de volta com
  // 'a' pelo mesmo tempo restaura a posicao que os testes de pulo abaixo
  // ja validam.
  await page.keyboard.down("a")
  await page.waitForTimeout(1000)
  await page.keyboard.up("a")
  await page.waitForTimeout(300)

  const chao = await alturaDoHeroi(page)
  await page.mouse.down({ button: "right" })
  await page.waitForTimeout(900)
  const pico = await alturaDoHeroi(page)
  await page.mouse.up({ button: "right" })
  confere("o botao direito levanta o heroi", pico !== null && chao !== null && pico < chao)

  await page.waitForTimeout(2500)
  const chaoW = await alturaDoHeroi(page)
  await page.keyboard.down("w")
  await page.waitForTimeout(900)
  const picoW = await alturaDoHeroi(page)
  await page.keyboard.up("w")
  confere("a tecla W levanta o heroi", picoW !== null && picoW < chaoW)

  // Toque curto: sobe menos que segurado. Um pulo cortado aterrissa em menos
  // de 90ms, entao uma unica medicao pontual (por exemplo 60ms depois de
  // soltar) deixa so ~30ms de folga entre soltar e medir -- instavel num
  // ambiente mais lento. Em vez de acertar o timing exato, amostramos
  // alturaDoHeroi tres vezes seguidas logo apos soltar e usamos o menor y (o
  // ponto mais alto atingido, que ocorre mais cedo, antes de o heroi comecar
  // a cair de volta). Isso tira a dependencia do timing sem afrouxar a
  // afirmacao.
  await page.waitForTimeout(2500)
  await page.keyboard.down("w")
  await page.waitForTimeout(120)
  await page.keyboard.up("w")
  const amostrasCurto = []
  for (let i = 0; i < 3; i++) {
    amostrasCurto.push(await alturaDoHeroi(page))
  }
  // Math.min(...[]) devolve Infinity, e picoW < Infinity e verdadeiro -- a
  // afirmacao passaria calada exatamente quando as tres amostras vierem
  // null (heroi nao encontrado, jogo morto, detector quebrado). Exigir
  // Number.isFinite fecha essa porta.
  const picoCurto = Math.min(...amostrasCurto.filter((y) => y !== null))
  confere(
    "segurar W sobe mais que tocar",
    Number.isFinite(picoCurto) && picoW < picoCurto
  )

  // '.' forca vitoria. E o caminho que desenhava texto no GLUT e agora
  // avisa a pagina. Na bancada isso vira window.__fim; na pagina do site o
  // sinal equivalente e o overlay HTML de fim de jogo ficar visivel.
  await page.keyboard.press(".")
  await page.waitForTimeout(600)
  const overlay = page.locator("[data-wasm-over]")
  if (await overlay.count()) {
    confere("o overlay de fim de jogo aparece", await overlay.isVisible())
    const texto = await overlay.locator("[data-wasm-over-message]").textContent()
    confere("o overlay traz uma mensagem", texto.trim().length > 0)

    // I1: a legenda anuncia R para reiniciar. Ate a correcao, o C++ so
    // chamava window.__jogo2d.fim() enquanto o jogo estava acabado -- quando
    // restartGame() zerava o estado ele simplesmente parava de chamar, e
    // nada avisava o JavaScript. O overlay ficava por cima do canvas com o
    // mouse morto (.demo-over cobre o canvas inteiro sem pointer-events:none,
    // e o mousedown do GLUT filtra por event.target == canvas).
    await page.keyboard.press("r")
    await page.waitForTimeout(400)
    confere("R esconde o overlay de fim de jogo", !(await overlay.isVisible()))

    // R ja devolveu o jogo (gameOver volta a false), entao '.' forca vitoria
    // de novo -- restaura o overlay visivel para o teste do botao "jogar de
    // novo" logo abaixo, que espera encontra-lo.
    await page.keyboard.press(".")
    await page.waitForSelector("[data-wasm-over]", { state: "visible", timeout: 5000 })
  } else {
    confere("o fim de jogo avisa a pagina com vitoria",
            (await page.evaluate(() => window.__fim)) === 1)
  }

  // Reiniciar pelo botao quando ele existir cobre o caminho de verdade que o
  // visitante clica na pagina do site; ccall direto e a porta dos fundos que
  // sobra so para a bancada, que nao tem esse botao.
  const botaoDnovo = page.locator("[data-wasm-restart]")
  if (await botaoDnovo.count()) {
    await botaoDnovo.click()
  } else {
    await page.evaluate(() => window.__modulo.ccall("reiniciarDoNavegador", null, [], []))
  }
  await page.waitForTimeout(600)
  // alturaDoHeroi so cobrava que existisse ALGUM pixel verde -- um reinicio
  // que deixasse o heroi perdido fora do spawn, ou a camera fora do lugar,
  // passaria do mesmo jeito. horizontalDoHeroi comparado contra xInicial (a
  // posicao medida logo no inicio, antes de qualquer movimento) cobra que o
  // heroi e a camera realmente voltem para o spawn, na mesma margem de 20px
  // usada pelas afirmacoes de movimento acima.
  const depoisDoReinicio = await horizontalDoHeroi(page)
  confere(
    "reiniciar devolve o heroi e a camera para o spawn",
    depoisDoReinicio !== null &&
      xInicial !== null &&
      Math.abs(depoisDoReinicio - xInicial) < 20
  )

  // C1: o GLUT do Emscripten escuta keydown/keyup na window em captura e da
  // preventDefault em Tab -- tecla que o jogo nao usa e a pagina precisa.
  // So faz sentido no alvo do site: e la que existem outros elementos
  // focaveis (rodape, botao de tema, links). A bancada (bench.html) e uma
  // pagina minima sem nenhum outro elemento tabulavel, e Tab sair do canvas
  // para fora da pagina (document.activeElement vira <body>) nao provaria
  // nada sobre a correcao -- aconteceria com ou sem o listener.
  const outrosFocaveis = await page.evaluate((sel) => {
    const candidatos = document.querySelectorAll("a[href], button, input, select, textarea, [tabindex]")
    const canvasEl = document.querySelector(sel)
    return Array.from(candidatos).filter((el) => el !== canvasEl && el.offsetParent !== null).length
  }, CANVAS)
  if (outrosFocaveis > 0) {
    const canvasHandle = await page.locator(CANVAS).elementHandle()
    await canvasHandle.focus()
    await page.keyboard.press("Tab")
    const saiuDoCanvas = await page.evaluate((canvasEl) => document.activeElement !== canvasEl, canvasHandle)
    confere("Tab move o foco para fora do canvas (sem armadilha de teclado)", saiuDoCanvas)
  } else {
    console.log("info  pulando o teste de Tab: alvo sem outro elemento focavel (bancada)")
  }

  confere("nenhum erro de pagina", erros.length === 0)
  if (erros.length) console.error(erros.join("\n"))

  await browser.close()

  if (falhas.length) {
    console.error(`\n${falhas.length} verificacao(oes) falharam`)
    process.exit(1)
  }
  console.log("\ntudo verificado")
})()
