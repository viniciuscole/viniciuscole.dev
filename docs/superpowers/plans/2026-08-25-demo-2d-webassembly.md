# Demo jogável do jogo 2D em WebAssembly — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer o jogo 2D em C++/OpenGL rodar jogável na página do projeto, compilado para WebAssembly nativo com Emscripten.

**Architecture:** Uma receita Docker com Emscripten aplica três patches sobre um clone raso do upstream num SHA fixo e produz `jogo.js`/`jogo.wasm`/`jogo.data`, commitados no repositório. Um novo tipo de demo (`wasm`) entra no dispatcher já existente, com partial, player JavaScript e folha de estilo próprios. Uma bancada em navegador de verdade (Chromium via Docker) é a única verificação capaz de pegar regressões de runtime do OpenGL emulado.

**Tech Stack:** Emscripten (`em++`), C++11, OpenGL/GLUT, Bridgetown 2.2.2, ERB, Ruby/Minitest, Playwright em Docker, Rake.

**Spec:** `docs/superpowers/specs/2026-08-25-demo-2d-webassembly-design.md`

## Global Constraints

- **Node 22** é obrigatório (o esbuild do Bridgetown usa `fs.globSync`, ausente no 20). Ver `.nvmrc`.
- **`em++`, nunca `emcc`** — o projeto é C++; o `emcc` falha com símbolos da stdlib indefinidos.
- **Upstream fixado no SHA `5910e9a0bf780dc739bc85cfe8a520851e7774cc`** de `https://github.com/viniciuscole/2D-Computer-Graphics`. Nunca clonar `main` sem SHA.
- **`git apply` que falha derruba a build.** Nunca seguir sem o patch: produziria um `.wasm` que aborta no primeiro círculo desenhado.
- **`docker run` sempre com `--user $(Process.uid):$(Process.gid)`** — sem isso o artefato nasce root dentro do repositório e a build seguinte exige sudo.
- **Artefatos são commitados; `demo2d:build` fica fora do `rake check`.** Quem clona o site não precisa de Docker nem de Emscripten.
- **A janela permanece 500x500.** É exigência do enunciado do trabalho, não preferência.
- **Nenhuma tecla de apresentação (`n`, `t`, `l`, `,`, `.`) pode aparecer na página.**
- **Todo teste novo é provado por remoção**: apagar o que ele guarda e ver a suíte ficar vermelha. Teste que não se sabe fazer falhar não é teste.
- Comentários e mensagens de commit em português, sem acentos nas mensagens de commit (padrão do repositório).

## Estrutura de arquivos

**Criar:**

| arquivo | responsabilidade |
|---|---|
| `build/2d/Dockerfile` | imagem com Emscripten fixado |
| `build/2d/build.sh` | aplica patches e compila |
| `build/2d/0001-triangle-fan.patch` | `GL_POLYGON` → `GL_TRIANGLE_FAN` |
| `build/2d/0002-fim-de-jogo-em-html.patch` | avisa a página; expõe `reiniciarDoNavegador` |
| `build/2d/0003-w-pula-e-esc-neutralizado.patch` | `W` pula; `ESC` deixa de sair |
| `build/2d/bench.html` | página mínima para verificar os artefatos isoladamente |
| `build/2d/verify.js` | driver Playwright, alvo via env `ALVO` |
| `src/demos/2d-graphics/jogo.{js,wasm,data}` | artefatos (gerados, commitados) |
| `src/_partials/demos/_wasm.erb` | marcação da demo |
| `src/_projects/2d-graphics.{en,pt}.md` | páginas do projeto |
| `frontend/javascript/wasm-player.js` | boot sob clique, overlay, reinício |
| `frontend/styles/demo.css` | casco comum às duas demos |
| `frontend/styles/wasm-demo.css` | estilo específico desta demo |
| `test/wasm_artifacts_test.rb` | integridade dos artefatos |
| `test/wasm_partial_test.rb` | ganchos, legenda, ausência das teclas de apresentação |
| `test/wasm_player_test.rb` | contrato do JavaScript |
| `test/demo_styles_test.rb` | classes emitidas têm estilo; imports |

**Modificar:**

| arquivo | mudança |
|---|---|
| `Rakefile` | namespace `demo2d` com `build` e `verify` |
| `plugins/builders/demo_helper.rb` | `DEMO_TYPES` ganha `"wasm"` |
| `src/_locales/{en,pt}.yml` | `demo.jsdos.*` e `demo.wasm.*` |
| `src/_partials/demos/_jsdos.erb` | chaves de tradução renomeadas |
| `frontend/styles/crt.css` | perde o casco comum |
| `frontend/styles/index.css` | importa `demo.css` e `wasm-demo.css` |
| `test/crt_test.rb` | classes movidas passam a ser cobradas de `demo.css` |

---

### Task 1: Receita de build e primeiros artefatos

Entrega: `rake demo2d:build` produz artefatos que renderizam o jogo.

**Files:**
- Create: `build/2d/Dockerfile`, `build/2d/build.sh`, `build/2d/0001-triangle-fan.patch`
- Modify: `Rakefile`
- Create (gerado): `src/demos/2d-graphics/jogo.js`, `jogo.wasm`, `jogo.data`

**Interfaces:**
- Consumes: nada.
- Produces: os três artefatos em `src/demos/2d-graphics/`. O módulo é uma factory global chamada `criarJogo2D`, com assinatura `criarJogo2D(opcoes) -> Promise<Module>`, onde `opcoes` aceita ao menos `canvas` (HTMLCanvasElement), `arguments` (Array<string>), `print`, `printErr`.

- [ ] **Step 1: Descobrir a versão do Emscripten e fixá-la**

Não invente uma tag. Pergunte à imagem qual versão ela traz:

```bash
docker run --rm emscripten/emsdk:latest emcc --version | head -1
```

Anote a versão devolvida (ex.: `4.0.14`) e use-a como tag no `Dockerfile` do passo seguinte, no lugar de `latest`.

- [ ] **Step 2: Escrever o Dockerfile**

`build/2d/Dockerfile` (troque `<VERSAO>` pela do passo 1):

```dockerfile
# Fixada de proposito: `latest` faria a saida mudar sem ninguem pedir, e o
# teste de integridade dos artefatos passaria a acusar deriva do toolchain
# como se fosse mudanca no jogo.
FROM emscripten/emsdk:<VERSAO>

# git para aplicar os patches sobre o clone.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

COPY build.sh /usr/local/bin/build-2d
RUN chmod +x /usr/local/bin/build-2d

ENTRYPOINT ["/usr/local/bin/build-2d"]
```

- [ ] **Step 3: Escrever o script de build**

`build/2d/build.sh`:

```bash
#!/bin/bash
# Aplica os patches do site sobre o fonte do trabalho e compila para
# WebAssembly. Roda dentro do container; /src e o clone, /patches sao os
# patches, /out recebe os artefatos.
set -euo pipefail

cd /src

for patch in /patches/*.patch; do
  echo "== aplicando $(basename "$patch")"
  # Sem --check antes: `git apply` ja falha inteiro ou nao aplica nada, e o
  # set -e derruba a build. Seguir sem o patch produziria um .wasm que aborta
  # no primeiro circulo desenhado.
  git apply --verbose "$patch"
done

# em++, nao emcc: o projeto e C++ e o emcc falha nos simbolos da stdlib.
# LEGACY_GL_EMULATION cobre o OpenGL em modo imediato (glBegin/glVertex2f).
# MODULARIZE evita que o modulo suba sozinho ao carregar o script, que e o
# que permite carregar a demo so no clique.
em++ -std=c++11 -O2 \
  main.cpp arena.cpp tinyxml2.cpp character.cpp hero.cpp enemy.cpp shot.cpp \
  -sLEGACY_GL_EMULATION=1 \
  -sALLOW_MEMORY_GROWTH=1 \
  -sEXIT_RUNTIME=0 \
  -sMODULARIZE=1 \
  -sEXPORT_NAME=criarJogo2D \
  -lGL -lglut \
  --preload-file arena_teste.svg \
  -o /out/jogo.js

ls -l /out/
```

- [ ] **Step 4: Escrever o patch 0001**

`build/2d/0001-triangle-fan.patch`:

```diff
--- a/circle.h
+++ b/circle.h
@@ -14,7 +14,10 @@ struct Circle {
     void draw() const {
         glColor3f(color[0], color[1], color[2]);
-        glBegin(GL_POLYGON);
+        // GL_POLYGON nao existe na emulacao de modo imediato do Emscripten:
+        // o runtime aborta com "unsupported immediate mode 9" no primeiro
+        // quadro. Para um poligono convexo o leque de triangulos desenha
+        // exatamente a mesma coisa.
+        glBegin(GL_TRIANGLE_FAN);
         for (int i = 0; i < 360; i++) {
             glVertex2f(cx + r * cos(i * M_PI / 180), cy + r * sin(i * M_PI / 180));
         }
```

Se o contexto não bater, gere o patch de verdade: clone o SHA fixo, edite `circle.h`, e rode `git diff > build/2d/0001-triangle-fan.patch`.

- [ ] **Step 5: Acrescentar a task de build ao Rakefile**

Depois do `namespace :game do ... end`:

```ruby
namespace :demo2d do
  # SHA fixo, nao `main`. Um upstream que andou faria os patches aplicarem
  # torto em silencio, e o resultado seria um .wasm que aborta no primeiro
  # quadro em vez de um erro de build.
  REPO_2D = "https://github.com/viniciuscole/2D-Computer-Graphics".freeze
  SHA_2D  = "5910e9a0bf780dc739bc85cfe8a520851e7774cc".freeze

  desc "Reconstroi o jogo 2D em WebAssembly a partir do fonte (exige Docker)"
  task :build do
    require "fileutils"
    require "tmpdir"

    destino = File.expand_path("src/demos/2d-graphics")
    receita = File.expand_path("build/2d")

    FileUtils.mkdir_p(destino)

    Dir.mktmpdir do |tmp|
      fonte = "#{tmp}/2d"
      sh "git clone #{REPO_2D} #{fonte}"
      sh "git -C #{fonte} checkout --detach #{SHA_2D}"
      sh "docker build -t viniciuscole-2d-build #{receita}"
      # Sem --user o container escreve os artefatos como root dentro do
      # repositorio, e a proxima reconstrucao precisa de sudo.
      sh "docker run --rm " \
         "--user #{Process.uid}:#{Process.gid} " \
         "-v #{fonte}:/src " \
         "-v #{receita}:/patches:ro " \
         "-v #{destino}:/out " \
         "viniciuscole-2d-build"
    end
  end
end
```

- [ ] **Step 6: Rodar a build**

Run: `rake demo2d:build`
Expected: termina sem erro e lista `jogo.js`, `jogo.wasm`, `jogo.data` em `/out/`. `jogo.wasm` na casa dos 180 KB.

- [ ] **Step 7: Escrever o teste de integridade dos artefatos**

`test/wasm_artifacts_test.rb`:

```ruby
require "test_helper"

# Guarda direto contra o defeito da Fase 2, onde a vendorizacao esqueceu tres
# arquivos e a demo nao bootava com a suite inteira verde. Aqui os tres
# artefatos sao verificados no fonte E no output: o build do site copia
# src/demos/ para output/, e ja aconteceu de a suite passar sobre um output
# que nao tinha o que a pagina pede.
class WasmArtifactsTest < Minitest::Test
  include OutputHelpers

  BASE = "demos/2d-graphics".freeze

  # Tamanhos minimos, nao exatos: o .wasm muda de tamanho a cada patch, e um
  # numero exato viraria churn a cada tarefa deste plano. O que estes pisos
  # pegam e o caso que importa — artefato ausente, vazio ou truncado.
  MINIMO_WASM = 150_000
  MINIMO_JS   = 100_000
  MINIMO_DATA = 2_000

  def test_the_three_artefacts_are_versioned_in_the_repository
    %w[jogo.js jogo.wasm jogo.data].each do |nome|
      caminho = ROOT.join("src", BASE, nome)
      assert caminho.file?, "faltou src/#{BASE}/#{nome} — rode `rake demo2d:build`"
    end
  end

  def test_the_three_artefacts_are_published
    %w[jogo.js jogo.wasm jogo.data].each do |nome|
      assert output("#{BASE}/#{nome}").file?,
        "#{nome} existe em src/ mas nao chegou em output/"
    end
  end

  def test_the_wasm_is_a_real_webassembly_module
    conteudo = ROOT.join("src", BASE, "jogo.wasm").binread(4)
    assert_equal "\x00asm".b, conteudo,
      "jogo.wasm nao comeca com a assinatura \\0asm de modulo WebAssembly"
  end

  def test_the_artefacts_are_not_truncated
    {
      "jogo.wasm" => MINIMO_WASM,
      "jogo.js"   => MINIMO_JS,
      "jogo.data" => MINIMO_DATA,
    }.each do |nome, minimo|
      tamanho = ROOT.join("src", BASE, nome).size
      assert tamanho >= minimo,
        "#{nome} tem #{tamanho} bytes, esperava ao menos #{minimo}. " \
        "Artefato truncado ou build incompleta."
    end
  end

  # MODULARIZE e o que permite carregar sob clique. Sem ele o modulo sobe
  # sozinho ao carregar o script e a demo comeca antes de alguem pedir.
  def test_the_module_is_a_factory_named_criarJogo2D
    js = ROOT.join("src", BASE, "jogo.js").read
    assert_includes js, "criarJogo2D",
      "jogo.js nao expoe a factory criarJogo2D — faltou -sMODULARIZE/-sEXPORT_NAME"
  end
end
```

- [ ] **Step 8: Provar que os testes falham quando devem**

```bash
mv src/demos/2d-graphics/jogo.wasm /tmp/jogo.wasm.bak
bin/bridgetown build && rake minitest 2>&1 | tail -20
```
Expected: FAIL em `test_the_three_artefacts_are_versioned_in_the_repository` e `test_the_wasm_is_a_real_webassembly_module`.

Restaure e confirme o verde:
```bash
mv /tmp/jogo.wasm.bak src/demos/2d-graphics/jogo.wasm
bin/bridgetown build && rake minitest
```
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add build/2d/ Rakefile src/demos/2d-graphics/ test/wasm_artifacts_test.rb
git commit -m "Receita de build do jogo 2D em WebAssembly

O patch 0001 troca GL_POLYGON por GL_TRIANGLE_FAN em circle.h. Sem ele o
runtime aborta com 'unsupported immediate mode 9' no primeiro quadro --
compila e linka limpo, e so quebra no navegador.

O upstream fica fixo num SHA para os patches nao aplicarem torto em
silencio, e git apply que falha derruba a build.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Bancada de verificação em navegador

Entrega: `rake demo2d:verify` abre um Chromium de verdade e prova que o jogo desenha e responde. É o único instrumento capaz de pegar uma regressão como o `GL_POLYGON`.

**Files:**
- Create: `build/2d/bench.html`, `build/2d/verify.js`
- Modify: `Rakefile`

**Interfaces:**
- Consumes: `criarJogo2D(opcoes) -> Promise<Module>` da Task 1.
- Produces: `build/2d/verify.js`, que lê a URL alvo de `process.env.ALVO`, espera o seletor `#canvas`, e devolve código de saída não-zero se qualquer afirmação falhar. Exporta a função `alturaDoHeroi(page)` internamente — tarefas seguintes estendem este arquivo, não criam outro.

- [ ] **Step 1: Escrever a página de bancada**

`build/2d/bench.html` — página mínima que carrega os artefatos isoladamente, sem o site em volta:

```html
<!doctype html>
<html lang="pt">
<head>
<meta charset="utf-8">
<title>Bancada — jogo 2D</title>
<style>
  body { background: #111; margin: 0; padding: 1rem;
         font: 14px ui-monospace, monospace; color: #ddd; }
  canvas { background: #000; display: block; }
</style>
</head>
<body>
  <canvas id="canvas" width="500" height="500" tabindex="1"></canvas>
  <div id="estado">carregando</div>
<script src="./jogo.js"></script>
<script>
  // O main() do jogo le o caminho do SVG de argv[1]. No navegador nao ha
  // linha de comando, entao o Emscripten injeta os argumentos aqui.
  criarJogo2D({
    canvas: document.getElementById("canvas"),
    arguments: ["arena_teste.svg"],
  }).then(function (mod) {
    window.__modulo = mod
    document.getElementById("estado").textContent = "pronto"
  })
</script>
</body>
</html>
```

- [ ] **Step 2: Escrever o driver**

`build/2d/verify.js`:

```javascript
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
```

- [ ] **Step 3: Acrescentar a task de verificação**

Dentro de `namespace :demo2d do`, depois de `task :build`:

```ruby
  IMAGEM_PLAYWRIGHT = "mcr.microsoft.com/playwright:v1.56.0-noble".freeze

  desc "Verifica em navegador de verdade que o jogo 2D desenha e responde (exige Docker)"
  task :verify do
    require "fileutils"
    require "tmpdir"

    receita = File.expand_path("build/2d")
    artefatos = File.expand_path("src/demos/2d-graphics")

    Dir.mktmpdir do |tmp|
      # A bancada precisa dos artefatos e da pagina no mesmo diretorio, porque
      # jogo.js busca jogo.wasm e jogo.data como irmaos.
      FileUtils.cp(Dir["#{artefatos}/jogo.*"], tmp)
      FileUtils.cp("#{receita}/bench.html", "#{tmp}/index.html")
      FileUtils.cp("#{receita}/verify.js", tmp)

      sh "docker run --rm --network host " \
         "--user #{Process.uid}:#{Process.gid} " \
         "-v #{tmp}:/work -w /work " \
         "-e ALVO=http://localhost:4123/ " \
         "#{IMAGEM_PLAYWRIGHT} " \
         "bash -c 'npm install --silent playwright@1.56.0 && " \
         "(python3 -m http.server 4123 &) && sleep 2 && node verify.js'"
    end
  end
```

- [ ] **Step 4: Rodar a verificação**

Run: `rake demo2d:verify`
Expected: cinco linhas `ok` e `tudo verificado`. Se o `GL_POLYGON` voltasse, a primeira linha viraria `FALHA` e a task sairia com código 1.

- [ ] **Step 5: Provar que a bancada detecta a regressão que ela existe para pegar**

**Não apague o arquivo do patch.** Diretório de patches vazio não é estado legítimo desta receita — ela deve rejeitá-lo, alto, e o `build.sh` tem uma guarda para isso. Um build que fecha limpo sem patch nenhum produz exatamente o artefato quebrado que estamos tentando detectar.

Em vez disso, faça o patch pedir o defeito de volta. Edite `build/2d/0001-triangle-fan.patch` trocando, na linha adicionada, `GL_TRIANGLE_FAN` por `GL_POLYGON`:

```bash
cp build/2d/0001-triangle-fan.patch /tmp/0001.bak
sed -i 's/^+        glBegin(GL_TRIANGLE_FAN);/+        glBegin(GL_POLYGON);/' \
    build/2d/0001-triangle-fan.patch
rake demo2d:build && rake demo2d:verify
```

O patch continua aplicando (o contexto não mudou) e a build fecha normalmente, mas o artefato produzido é o que aborta no primeiro quadro.

Expected: `rake demo2d:build` termina bem, e `rake demo2d:verify` **FALHA** — o canvas fica preto e aparece `Aborted(unsupported immediate mode 9)`.

Restaure:
```bash
cp /tmp/0001.bak build/2d/0001-triangle-fan.patch
rake demo2d:build && rake demo2d:verify
```
Expected: verde.

- [ ] **Step 6: Provar a guarda de patches ausentes**

```bash
mv build/2d/0001-triangle-fan.patch /tmp/
rake demo2d:build
```
Expected: FALHA com a mensagem explícita da guarda, não com um críptico `No such file or directory` do `git apply`.

```bash
mv /tmp/0001-triangle-fan.patch build/2d/
rake demo2d:build
```
Expected: volta a construir.

- [ ] **Step 7: Commit**

```bash
git add build/2d/bench.html build/2d/verify.js Rakefile src/demos/2d-graphics/
git commit -m "Bancada de verificacao do jogo 2D em navegador

Nenhum teste estatico pega uma regressao de runtime do OpenGL emulado.
A primeira compilacao deste port linkou limpa e abortava no primeiro
quadro; so abrir um navegador pegou.

Fica fora do rake check porque exige Docker e uma imagem de navegador.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Fim de jogo em HTML e reinício exposto

Entrega: o C++ avisa a página quando o jogo acaba, e a página consegue reiniciar sem eventos sintéticos.

**Files:**
- Create: `build/2d/0002-fim-de-jogo-em-html.patch`
- Modify: `build/2d/build.sh`, `build/2d/bench.html`, `build/2d/verify.js`
- Regenerate: `src/demos/2d-graphics/jogo.*`

**Interfaces:**
- Consumes: a factory `criarJogo2D` da Task 1; `confere`/`alturaDoHeroi` da Task 2.
- Produces:
  - O módulo chama `window.__jogo2d.fim(venceu)` a cada quadro enquanto o jogo está acabado, onde `venceu` é `1` (vitória) ou `0` (derrota). **O lado JavaScript precisa ser idempotente.**
  - `Module.ccall("reiniciarDoNavegador", null, [], [])` reinicia a partida.

- [ ] **Step 1: Escrever o patch 0002**

`build/2d/0002-fim-de-jogo-em-html.patch`. As duas telas de fim de jogo em `main.cpp` desenhavam texto com fontes bitmap do GLUT, que o Emscripten não implementa (`glRasterPos2f`, `glutBitmapCharacter`, `glutBitmapHelvetica18`). Sem substituição a tela fica inteiramente preta.

```diff
--- a/main.cpp
+++ b/main.cpp
@@
+#ifdef __EMSCRIPTEN__
+#include <emscripten.h>
+#endif
+
@@
     if (gameOver && gameLost) {
-        glRasterPos2f(cameraX + 17, arena.height / 2 + 1);
-        const char* message = "Voce perdeu! Pressione R para reiniciar.";
-        for (const char* c = message; *c != '\0'; c++) {
-            glutBitmapCharacter(GLUT_BITMAP_HELVETICA_18, *c);
-        }
+        // As fontes bitmap do GLUT nao existem no Emscripten. Onde o C++
+        // desenhava texto no centro da tela, agora pede a pagina que mostre
+        // texto no centro da tela -- traduzido e no tipo do site. Chamado a
+        // cada quadro enquanto o jogo esta acabado: o lado JS e idempotente.
+        EM_ASM({ if (window.__jogo2d) window.__jogo2d.fim($0); }, 0);
     }
     else if (gameOver && gameWon){
-        glRasterPos2f(cameraX + 17, arena.height / 2 + 1);
-        const char* message = "Voce venceu! Pressione R para reiniciar.";
-        for (const char* c = message; *c != '\0'; c++) {
-            glutBitmapCharacter(GLUT_BITMAP_HELVETICA_18, *c);
-        }
+        EM_ASM({ if (window.__jogo2d) window.__jogo2d.fim($0); }, 1);
     }
@@
+// Chamado pelo botao "jogar de novo" do overlay. Existe para o botao nao
+// depender de disparar um KeyboardEvent sintetico -- foi exatamente ai que
+// o teclado da demo do js-dos deu trabalho na Fase 2.
+extern "C" EMSCRIPTEN_KEEPALIVE void reiniciarDoNavegador() {
+    restartGame();
+}
+
```

Confira os textos exatos das duas mensagens no fonte antes de gerar o patch — se não baterem, o `git apply` falha (e é para falhar). Gere o patch de verdade com `git diff` sobre o clone no SHA fixo.

- [ ] **Step 2: Exportar a função nova no build.sh**

Em `build/2d/build.sh`, acrescente às flags do `em++`, antes de `-lGL`:

```bash
  -sEXPORTED_FUNCTIONS='["_main","_reiniciarDoNavegador"]' \
  -sEXPORTED_RUNTIME_METHODS='["ccall"]' \
```

- [ ] **Step 3: Apagar o andaime do texto do GLUT**

A Task 1 precisou criar `build/2d/glut-text-stubs.js`, um shim no-op para os três símbolos de fonte bitmap do GLUT (`glRasterPos2f`, `glutBitmapCharacter`, `glutBitmapHelvetica18`) que o Emscripten declara mas nunca implementa. Ele existia só para o link fechar enquanto o C++ ainda chamava essas funções.

O patch 0002 remove essas chamadas. **A partir daqui o shim é peso morto e precisa sair:**

```bash
git rm build/2d/glut-text-stubs.js
```

E remova a flag `--js-library` correspondente do `build/2d/build.sh`.

Isto não é limpeza cosmética. Mantido, o shim faria uma reintrodução futura de texto do GLUT **linkar em silêncio e não desenhar nada**, em vez de quebrar o link e avisar. O erro de link é a única coisa que sinaliza que aquela API não existe aqui.

Se depois de remover os dois o `rake demo2d:build` falhar com `undefined symbol` em algum desses três nomes, então o patch 0002 não removeu todas as chamadas — procure a que sobrou em vez de devolver o shim.

- [ ] **Step 4: Reconstruir**

Run: `rake demo2d:build`
Expected: sem erro.

- [ ] **Step 5: Ensinar a bancada a receber o aviso**

Em `build/2d/bench.html`, antes da chamada a `criarJogo2D`:

```javascript
  // Espelha o que o site faz: recebe o aviso de fim de jogo do C++.
  window.__jogo2d = {
    fim: function (venceu) { window.__fim = venceu },
  }
```

- [ ] **Step 6: Estender a verificação**

Em `build/2d/verify.js`, antes de `confere("nenhum erro de pagina", ...)`:

```javascript
  // '.' forca vitoria. E o caminho que desenhava texto no GLUT e agora
  // avisa a pagina.
  await page.keyboard.press(".")
  await page.waitForTimeout(600)
  const fim = await page.evaluate(() => window.__fim)
  confere("o fim de jogo avisa a pagina com vitoria", fim === 1)

  await page.evaluate(() => window.__modulo.ccall("reiniciarDoNavegador", null, [], []))
  await page.waitForTimeout(600)
  const depoisDoReinicio = await alturaDoHeroi(page)
  confere("reiniciarDoNavegador devolve o jogo", depoisDoReinicio !== null)
```

- [ ] **Step 7: Verificar**

Run: `rake demo2d:verify`
Expected: todas `ok`, incluindo as duas novas.

- [ ] **Step 8: Provar que a nova verificação falha sem o patch**

```bash
mv build/2d/0002-fim-de-jogo-em-html.patch /tmp/0002.bak
rake demo2d:build
```
Expected: a build FALHA no link, com `undefined symbol: reiniciarDoNavegador` (o `EXPORTED_FUNCTIONS` cobra a função que o patch cria). Esse é o comportamento correto: a receita não deixa produzir artefato incoerente.

```bash
mv /tmp/0002.bak build/2d/0002-fim-de-jogo-em-html.patch
rake demo2d:build && rake demo2d:verify
```
Expected: verde.

- [ ] **Step 9: Commit**

```bash
git add build/2d/ src/demos/2d-graphics/
git commit -m "Fim de jogo em HTML e reinicio exposto ao navegador

A tela de fim de jogo era so texto desenhado com fontes bitmap do GLUT,
que o Emscripten nao implementa -- sem substituicao ela fica inteiramente
preta, e o enunciado do trabalho exige a mensagem.

reiniciarDoNavegador existe para o botao nao depender de KeyboardEvent
sintetico.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: `W` pula e `ESC` deixa de encerrar

Entrega: alternativa confortável ao botão direito, e nenhuma tecla que mate a demo sem volta.

**Files:**
- Create: `build/2d/0003-w-pula-e-esc-neutralizado.patch`
- Modify: `build/2d/verify.js`
- Regenerate: `src/demos/2d-graphics/jogo.*`

**Interfaces:**
- Consumes: `alturaDoHeroi(page)` e `confere` da Task 2.
- Produces: nenhuma interface nova de código. Comportamento: `W` pula, com altura proporcional ao tempo segurado; `ESC` não faz nada.

- [ ] **Step 1: Escrever o patch 0003**

`build/2d/0003-w-pula-e-esc-neutralizado.patch`:

```diff
--- a/main.cpp
+++ b/main.cpp
@@
         case 'w':
         case 'W':
             keyStatus[(int)('w')] = 1;
+            // O enunciado exige o pulo no botao direito, e ele continua
+            // valendo. W e alternativa: em trackpad, segurar o botao direito
+            // enquanto se anda e mira e desconfortavel. jump() ja se protege
+            // com !isJumping && !isFalling, entao a repeticao de tecla ao
+            // segurar nao retriga o pulo.
+            player.jump();
             break;
@@
-        case 27 :
-            exit(0);
+        // 27 e ESC. Num executavel de desktop sair e razoavel; numa pagina
+        // nao existe "sair", e quem encostasse nele ficaria com um canvas
+        // morto e nenhum caminho de volta alem de recarregar. O enunciado
+        // nao pede ESC.
     }
     glutPostRedisplay();
 }
@@
 void keyup(unsigned char key, int x, int y)
 {
     keyStatus[(int)(key)] = 0;
+    // Soltar W corta o pulo, igual a soltar o botao direito. E o que da o
+    // controle de altura que o enunciado descreve.
+    if (key == 'w' || key == 'W') {
+        player.stopJump();
+    }
     glutPostRedisplay();
 }
```

- [ ] **Step 2: Reconstruir**

Run: `rake demo2d:build`
Expected: sem erro.

- [ ] **Step 3: Estender a verificação**

Em `build/2d/verify.js`, depois da conferência do botão direito:

```javascript
  await page.waitForTimeout(2500)
  const chaoW = await alturaDoHeroi(page)
  await page.keyboard.down("w")
  await page.waitForTimeout(900)
  const picoW = await alturaDoHeroi(page)
  await page.keyboard.up("w")
  confere("a tecla W levanta o heroi", picoW !== null && picoW < chaoW)

  // Toque curto: sobe menos que segurado. Medido durante a subida, nao
  // depois de soltar -- um pulo cortado aterrissa em menos de 90ms e uma
  // medicao tardia registra zero e parece falha quando nao e.
  await page.waitForTimeout(2500)
  await page.keyboard.down("w")
  await page.waitForTimeout(120)
  await page.keyboard.up("w")
  await page.waitForTimeout(60)
  const picoCurto = await alturaDoHeroi(page)
  confere("segurar W sobe mais que tocar", picoW < picoCurto)

  // ESC nao pode mais matar a demo.
  await page.waitForTimeout(2500)
  await page.keyboard.press("Escape")
  await page.waitForTimeout(500)
  const vivoDepoisDoEsc = await alturaDoHeroi(page)
  confere("ESC nao encerra o jogo", vivoDepoisDoEsc !== null)
```

- [ ] **Step 4: Verificar**

Run: `rake demo2d:verify`
Expected: todas `ok`. Referência das medidas obtidas no probe: `W` tocado ~21 px, `W` segurado ~147 px, botão direito segurado ~137 px.

- [ ] **Step 5: Commit**

```bash
git add build/2d/ src/demos/2d-graphics/
git commit -m "W pula e ESC deixa de encerrar o jogo 2D

W e aditivo: o botao direito, que o enunciado exige, continua igual.
ESC chamava exit(0), o que numa pagina deixa o canvas morto sem volta.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Traduções separadas por tipo de demo

Entrega: as chaves específicas de cada demo deixam de disputar o mesmo espaço.

**Files:**
- Modify: `src/_locales/en.yml`, `src/_locales/pt.yml`, `src/_partials/demos/_jsdos.erb`
- Test: `test/locales_test.rb`

**Interfaces:**
- Consumes: nada.
- Produces: as chaves `demo.jsdos.weight`, `demo.jsdos.license`, `demo.jsdos.license_text`, `demo.jsdos.commands.*`, `demo.jsdos.keypad.*`, e as novas `demo.wasm.weight`, `demo.wasm.controls.title`, `demo.wasm.controls.walk`, `demo.wasm.controls.jump`, `demo.wasm.controls.shoot`, `demo.wasm.controls.aim`, `demo.wasm.controls.restart`, `demo.wasm.over.won`, `demo.wasm.over.lost`, `demo.wasm.over.again`, `demo.wasm.credits`. Permanecem comuns em `demo.*`: `label`, `start`, `failed`, `missing_bundle`, `noscript`.

- [ ] **Step 1: Mover as chaves específicas do jsdos**

Em `src/_locales/en.yml`, sob `demo:`, mova `weight`, `license`, `license_text`, `commands:` e `keypad:` para dentro de um novo `jsdos:`. Deixe `label`, `start`, `failed`, `missing_bundle` e `noscript` onde estão. Faça o mesmo em `pt.yml`.

- [ ] **Step 2: Acrescentar as chaves do wasm**

Em `src/_locales/en.yml`, sob `demo:`:

```yaml
    wasm:
      weight: "Loads about 380 KB of WebAssembly."
      controls:
        title: "Controls"
        walk: "walk"
        jump: "hold to jump — the longer you hold, the higher"
        shoot: "shoot"
        aim: "move the mouse to aim the arm"
        restart: "restart"
      over:
        won: "You made it across."
        lost: "You were hit."
        again: "Play again"
      credits: "SVG arena parsed with tinyxml2 (zlib licence)."
```

Em `src/_locales/pt.yml`:

```yaml
    wasm:
      weight: "Carrega cerca de 380 KB de WebAssembly."
      controls:
        title: "Controles"
        walk: "andar"
        jump: "segure para pular — quanto mais tempo, mais alto"
        shoot: "atirar"
        aim: "mova o mouse para mirar o braço"
        restart: "recomeçar"
      over:
        won: "Você atravessou."
        lost: "Você foi atingido."
        again: "Jogar de novo"
      credits: "Arena em SVG lida com tinyxml2 (licença zlib)."
```

- [ ] **Step 3: Atualizar o partial do jsdos**

Em `src/_partials/demos/_jsdos.erb`, troque cada `t("demo.weight")` por `t("demo.jsdos.weight")`, `t("demo.license")` por `t("demo.jsdos.license")`, `t("demo.license_text")` por `t("demo.jsdos.license_text")`, `t("demo.commands.…")` por `t("demo.jsdos.commands.…")` e `t("demo.keypad.…")` por `t("demo.jsdos.keypad.…")`. Não toque em `demo.label`, `demo.start`, `demo.failed`, `demo.missing_bundle` nem `demo.noscript`.

- [ ] **Step 4: Escrever o teste que pega chave órfã**

Acrescente a `test/locales_test.rb`:

```ruby
  # Renomear chaves de traducao falha em silencio: o Rails I18n devolve
  # "translation missing: ..." dentro do HTML e o build passa. Este teste le
  # os partials, extrai cada t("...") e cobra que a chave exista nos dois
  # idiomas.
  def test_every_translation_key_used_by_the_demo_partials_exists
    tabelas = {
      "en" => YAML.load_file(ROOT.join("src/_locales/en.yml")).fetch("en"),
      "pt" => YAML.load_file(ROOT.join("src/_locales/pt.yml")).fetch("pt"),
    }

    Dir.glob(ROOT.join("src/_partials/demos/*.erb")).sort.each do |arquivo|
      chaves = File.read(arquivo).scan(/\bt\("([a-z0-9_.]+)"/).flatten.uniq

      chaves.each do |chave|
        tabelas.each do |idioma, tabela|
          valor = chave.split(".").reduce(tabela) do |nivel, parte|
            nivel.is_a?(Hash) ? nivel[parte] : nil
          end
          refute_nil valor,
            "#{File.basename(arquivo)} usa t(\"#{chave}\"), que nao existe em #{idioma}.yml"
        end
      end
    end
  end
```

- [ ] **Step 5: Provar que o teste falha**

Renomeie uma chave só no `pt.yml` (ex.: `weight` → `weight_x` dentro de `jsdos:`), então:

Run: `bin/bridgetown build && rake minitest 2>&1 | tail -20`
Expected: FAIL com `_jsdos.erb usa t("demo.jsdos.weight"), que nao existe em pt.yml`.

Desfaça e confirme:
Run: `bin/bridgetown build && rake minitest`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/_locales/ src/_partials/demos/_jsdos.erb test/locales_test.rb
git commit -m "Separa as traducoes por tipo de demo

Com dois tipos, demo.weight dizendo 'emulador DOS, 2,1 MB' e
demo.commands.* falando de jogo da velha no nivel de cima vira
ambiguidade. O que e comum fica em demo.*; o resto desce para
demo.jsdos.* e demo.wasm.*.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Dispatcher, partial e páginas do projeto

Entrega: a página do projeto existe nos dois idiomas e renderiza a marcação da demo.

**Files:**
- Modify: `plugins/builders/demo_helper.rb`
- Create: `src/_partials/demos/_wasm.erb`, `src/_projects/2d-graphics.en.md`, `src/_projects/2d-graphics.pt.md`
- Test: `test/wasm_partial_test.rb`, `test/demo_dispatcher_test.rb`

**Interfaces:**
- Consumes: as chaves `demo.wasm.*` da Task 5; os artefatos da Task 1.
- Produces: a marcação com os ganchos `data-wasm`, `data-wasm-base`, `data-wasm-frame`, `data-wasm-start`, `data-wasm-screen`, `data-wasm-canvas`, `data-wasm-error`, `data-wasm-over`, `data-wasm-over-message`, `data-wasm-restart`, mais os atributos `data-texto-vitoria` e `data-texto-derrota` acrescentados na Task 7. O player da Task 7 depende destes nomes exatos.

- [ ] **Step 1: Aceitar o tipo no dispatcher**

Em `plugins/builders/demo_helper.rb`:

```ruby
  DEMO_TYPES = %w[none jsdos wasm].freeze
```

- [ ] **Step 2: Escrever o partial**

`src/_partials/demos/_wasm.erb`:

```erb
<% base = resource.data.dig(:demo, :base).to_s %>
<section class="demo demo-wasm"
         data-wasm
         data-wasm-base="<%= base %>"
         aria-label="<%= t("demo.label") %>">

  <% if base.empty? %>
    <p class="demo-error"><%= t("demo.missing_bundle") %></p>
  <% else %>
    <div class="demo-frame" data-wasm-frame>
      <%# Nasce desligado: sem JavaScript o clique nao faz nada, e o player
          liga o botao quando esta pronto para atender. %>
      <button class="demo-start" type="button" data-wasm-start disabled>
        <%= t("demo.start") %>
      </button>
      <p class="demo-weight"><%= t("demo.wasm.weight") %></p>
      <noscript>
        <p class="demo-weight">
          <%= t("demo.noscript") %>
          <a href="<%= resource.data.repo %>"><%= resource.data.repo.to_s.sub("https://", "") %></a>
        </p>
      </noscript>
    </div>

    <div class="demo-screen" data-wasm-screen hidden>
      <canvas width="500" height="500" tabindex="0" data-wasm-canvas></canvas>

      <%# O C++ desenhava esta mensagem no centro da tela com fontes bitmap
          do GLUT. Aqui ela e HTML: traduzida e no tipo do site. %>
      <div class="demo-over" data-wasm-over hidden>
        <p data-wasm-over-message></p>
        <button type="button" data-wasm-restart><%= t("demo.wasm.over.again") %></button>
      </div>
    </div>

    <p class="demo-error" data-wasm-error hidden>
      <%= t("demo.failed") %>
      <a href="<%= resource.data.repo %>"><%= resource.data.repo.to_s.sub("https://", "") %></a>
    </p>
  <% end %>

  <div class="demo-instructions">
    <h2><%= t("demo.wasm.controls.title") %></h2>
    <ul>
      <li><code>A</code> <code>D</code> — <%= t("demo.wasm.controls.walk") %></li>
      <li><%= t("demo.wasm.controls.jump") %> — <code>W</code></li>
      <li><%= t("demo.wasm.controls.shoot") %></li>
      <li><%= t("demo.wasm.controls.aim") %></li>
      <li><code>R</code> — <%= t("demo.wasm.controls.restart") %></li>
    </ul>
  </div>

  <p class="demo-license"><%= t("demo.wasm.credits") %></p>
</section>
```

- [ ] **Step 3: Escrever o front matter das duas páginas**

`src/_projects/2d-graphics.en.md`:

```markdown
---
title: Side-Scrolling Game in C++ and OpenGL
locale: en
slug: 2d-graphics
year: 2024
featured: true
order: 2
summary: A side-scrolling shooter in C++ with OpenGL and GLUT, reading its arena from an SVG file, compiled to WebAssembly to run here.
tech: [C++, OpenGL, GLUT, Emscripten, WebAssembly]
repo: https://github.com/viniciuscole/2D-Computer-Graphics
demo:
  type: wasm
  base: /demos/2d-graphics/jogo
---

Corpo escrito na Task 9.
```

`src/_projects/2d-graphics.pt.md`:

```markdown
---
title: Jogo de Rolagem Lateral em C++ e OpenGL
locale: pt
slug: 2d-graphics
year: 2024
featured: true
order: 2
summary: Um jogo de rolagem lateral em C++ com OpenGL e GLUT, que lê sua arena de um arquivo SVG, compilado para WebAssembly para rodar aqui.
tech: [C++, OpenGL, GLUT, Emscripten, WebAssembly]
repo: https://github.com/viniciuscole/2D-Computer-Graphics
demo:
  type: wasm
  base: /demos/2d-graphics/jogo
---

Corpo escrito na Task 9.
```

- [ ] **Step 4: Escrever o teste do partial**

`test/wasm_partial_test.rb`:

```ruby
require "test_helper"

class WasmPartialTest < Minitest::Test
  include OutputHelpers

  EN = "projects/2d-graphics/index.html".freeze
  PT = "pt/projects/2d-graphics/index.html".freeze

  def test_the_project_page_renders_the_wasm_demo
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      assert_includes corpo, 'class="demo demo-wasm"',
        "#{pagina} nao renderizou a demo wasm"
      refute_includes corpo, 'class="demo demo-none"',
        "#{pagina} ainda mostra o placeholder"
    end
  end

  def test_the_demo_points_at_the_artefacts
    assert_includes page_body(EN), 'data-wasm-base="/demos/2d-graphics/jogo"'
  end

  def test_the_hooks_the_player_depends_on_exist
    corpo = page_body(EN)
    %w[data-wasm data-wasm-base data-wasm-frame data-wasm-start
       data-wasm-screen data-wasm-canvas data-wasm-error
       data-wasm-over data-wasm-over-message data-wasm-restart].each do |gancho|
      assert_includes corpo, gancho, "faltou o gancho #{gancho}"
    end
  end

  # A janela e 500x500 por exigencia do enunciado do trabalho ("a janela de
  # visualizacao sera quadrada ... exibida em uma janela de 500x500 pixel").
  # Nao e preferencia visual, e conformidade com a especificacao avaliada.
  def test_the_canvas_keeps_the_size_the_assignment_requires
    corpo = page_body(EN)
    assert_includes corpo, 'width="500"'
    assert_includes corpo, 'height="500"'
  end

  # As teclas n, t, l, virgula e ponto sao roteiro de apresentacao para a
  # banca, nao controles de jogo. Foi decidido nao expo-las.
  def test_the_presentation_shortcuts_are_not_documented_on_the_page
    [EN, PT].each do |pagina|
      instrucoes = page_body(pagina)[/<div class="demo-instructions">.*?<\/div>/m]
      refute_nil instrucoes, "#{pagina} nao tem o bloco de instrucoes"

      ["<code>N</code>", "<code>T</code>", "<code>L</code>",
       "<code>,</code>", "<code>.</code>"].each do |tecla|
        refute_includes instrucoes, tecla,
          "#{pagina} expoe #{tecla}, que e atalho de apresentacao e nao controle"
      end
    end
  end

  def test_the_page_credits_the_vendored_parser
    assert_includes page_body(EN), "tinyxml2"
  end
end
```

- [ ] **Step 5: Acrescentar o tipo ao teste do dispatcher**

Em `test/demo_dispatcher_test.rb`, acrescente:

```ruby
  def test_wasm_is_a_known_demo_type
    assert_includes Builders::DemoHelper::DEMO_TYPES, "wasm"
  end
```

- [ ] **Step 6: Construir e rodar**

Run: `bin/bridgetown build && rake minitest`
Expected: PASS.

- [ ] **Step 7: Provar que os testes falham**

Troque `type: wasm` por `type: wasmm` em `src/_projects/2d-graphics.en.md`, então:

Run: `bin/bridgetown build && rake minitest 2>&1 | tail -20`
Expected: FAIL em `test_the_project_page_renders_the_wasm_demo`.

Desfaça. Depois acrescente `<li><code>L</code> — carga</li>` ao bloco de instruções do partial:

Run: `bin/bridgetown build && rake minitest 2>&1 | tail -20`
Expected: FAIL em `test_the_presentation_shortcuts_are_not_documented_on_the_page`.

Desfaça e confirme verde.

- [ ] **Step 8: Commit**

```bash
git add plugins/builders/demo_helper.rb src/_partials/demos/_wasm.erb \
        src/_projects/2d-graphics.en.md src/_projects/2d-graphics.pt.md \
        test/wasm_partial_test.rb test/demo_dispatcher_test.rb
git commit -m "Pagina do projeto 2D e partial da demo wasm

O dispatcher da Fase 1 previa isso: um tipo novo em DEMO_TYPES mais um
partial, sem reformar nada.

O canvas fica em 500x500 porque o enunciado do trabalho exige, e as
teclas de apresentacao ficam fora da legenda por decisao.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Player JavaScript

Entrega: a demo carrega sob clique, o menu de contexto não atrapalha o pulo, e o fim de jogo aparece traduzido.

**Files:**
- Create: `frontend/javascript/wasm-player.js`
- Modify: `frontend/javascript/index.js`
- Test: `test/wasm_player_test.rb`

**Interfaces:**
- Consumes: os ganchos da Task 6; a factory `criarJogo2D` e o contrato `window.__jogo2d.fim(venceu)` das Tasks 1 e 3.
- Produces: nenhuma interface para outras tarefas.

- [ ] **Step 1: Escrever o player**

`frontend/javascript/wasm-player.js`:

```javascript
// Carrega o jogo 2D compilado para WebAssembly, sob clique. Nada e baixado
// antes disso: sao ~380 KB entre .js, .wasm e .data.
const TEMPO_LIMITE = 30000

function iniciar(raiz) {
  // getAttribute, nao dataset.wasmBase: o nome do gancho aparece literal no
  // codigo, e o teste que cobra "todo gancho emitido e lido por alguem"
  // consegue enxerga-lo. Com dataset o nome vira camelCase e some.
  const base = raiz.getAttribute("data-wasm-base")
  const quadro = raiz.querySelector("[data-wasm-frame]")
  const botao = raiz.querySelector("[data-wasm-start]")
  const tela = raiz.querySelector("[data-wasm-screen]")
  const canvas = raiz.querySelector("[data-wasm-canvas]")
  const erro = raiz.querySelector("[data-wasm-error]")
  const fim = raiz.querySelector("[data-wasm-over]")
  const mensagem = raiz.querySelector("[data-wasm-over-message]")
  const dnovo = raiz.querySelector("[data-wasm-restart]")

  if (!base || !quadro || !botao || !tela || !canvas || !erro) return

  const textos = {
    won: raiz.dataset.textoVitoria,
    lost: raiz.dataset.textoDerrota,
  }

  botao.disabled = false

  botao.addEventListener("click", () => {
    botao.disabled = true
    quadro.hidden = true
    tela.hidden = false

    const limite = setTimeout(() => {
      tela.hidden = true
      erro.hidden = false
    }, TEMPO_LIMITE)

    // O botao direito pula. Sem isto o navegador abre o menu de contexto
    // em cima do jogo a cada pulo. Verificado: cancelar o contextmenu nao
    // impede o mousedown de chegar ao Emscripten.
    canvas.addEventListener("contextmenu", (evento) => evento.preventDefault())

    // O C++ chama isto a cada quadro enquanto o jogo esta acabado, entao
    // precisa ser idempotente.
    window.__jogo2d = {
      fim(venceu) {
        if (!fim || !fim.hidden) return
        mensagem.textContent = venceu ? textos.won : textos.lost
        fim.hidden = false
      },
    }

    const script = document.createElement("script")
    script.src = `${base}.js`
    script.onerror = () => {
      clearTimeout(limite)
      tela.hidden = true
      erro.hidden = false
    }
    script.onload = () => {
      window
        .criarJogo2D({
          canvas,
          // O main() do jogo le o caminho do SVG de argv[1]. No navegador
          // nao ha linha de comando; o Emscripten injeta os argumentos aqui.
          arguments: ["arena_teste.svg"],
        })
        .then((modulo) => {
          clearTimeout(limite)
          canvas.focus()

          if (dnovo) {
            dnovo.addEventListener("click", () => {
              modulo.ccall("reiniciarDoNavegador", null, [], [])
              fim.hidden = true
              canvas.focus()
            })
          }
        })
        .catch(() => {
          clearTimeout(limite)
          tela.hidden = true
          erro.hidden = false
        })
    }
    document.head.appendChild(script)
  })
}

document.querySelectorAll("[data-wasm]").forEach(iniciar)
```

- [ ] **Step 2: Passar os textos traduzidos ao player**

O player precisa das mensagens de fim de jogo, que só o ERB conhece. Em `src/_partials/demos/_wasm.erb`, acrescente dois atributos à `<section>`:

```erb
         data-texto-vitoria="<%= t("demo.wasm.over.won") %>"
         data-texto-derrota="<%= t("demo.wasm.over.lost") %>"
```

- [ ] **Step 3: Importar o player**

Em `frontend/javascript/index.js`, acrescente na mesma forma que o player do js-dos já é importado:

```javascript
import "./wasm-player.js"
```

- [ ] **Step 4: Escrever o teste do contrato**

`test/wasm_player_test.rb`:

```ruby
require "test_helper"

class WasmPlayerTest < Minitest::Test
  include OutputHelpers

  def js
    ROOT.join("frontend/javascript/wasm-player.js").read
  end

  def test_the_player_exists_and_is_imported
    assert ROOT.join("frontend/javascript/wasm-player.js").file?
    assert_includes ROOT.join("frontend/javascript/index.js").read, "wasm-player"
  end

  # Cada gancho que o partial emite precisa ser lido por alguem. Um data-*
  # renomeado so de um lado nao quebra o build nem o HTML: a demo apenas
  # deixa de funcionar em silencio.
  def test_the_player_reads_every_hook_the_partial_emits
    corpo = page_body("projects/2d-graphics/index.html")
    ganchos = corpo.scan(/data-wasm-[a-z-]+/).uniq

    ganchos.each do |gancho|
      # o dataset em JS usa camelCase; o seletor usa o nome cru
      assert_includes js, gancho, "o player nao le o gancho #{gancho}"
    end
  end

  # O botao direito pula (exigencia do enunciado). Sem cancelar o
  # contextmenu, cada pulo abre o menu do navegador em cima do jogo.
  def test_the_player_suppresses_the_context_menu
    assert_includes js, "contextmenu"
    assert_includes js, "preventDefault"
  end

  # O C++ chama fim() a cada quadro enquanto o jogo esta acabado.
  def test_the_game_over_handler_is_idempotent
    assert_includes js, "!fim.hidden",
      "fim() precisa sair cedo quando o overlay ja esta visivel"
  end

  # Reiniciar via funcao exportada, nao via KeyboardEvent sintetico.
  def test_restart_calls_the_exported_function
    assert_includes js, 'ccall("reiniciarDoNavegador"'
    refute_includes js, "KeyboardEvent",
      "o reinicio nao deve depender de evento de teclado sintetico"
  end

  def test_nothing_is_downloaded_before_the_click
    assert_includes js, 'addEventListener("click"',
      "a demo tem que carregar sob clique"
  end
end
```

- [ ] **Step 5: Construir e rodar**

Run: `npm run esbuild && bin/bridgetown build && rake minitest`
Expected: PASS.

- [ ] **Step 6: Provar que os testes falham**

Remova a linha do `contextmenu` do player:

Run: `npm run esbuild && bin/bridgetown build && rake minitest 2>&1 | tail -20`
Expected: FAIL em `test_the_player_suppresses_the_context_menu`.

Desfaça. Depois troque `data-wasm-restart` por `data-wasm-again` só no partial:

Run: `npm run esbuild && bin/bridgetown build && rake minitest 2>&1 | tail -20`
Expected: FAIL em `test_the_player_reads_every_hook_the_partial_emits`.

Desfaça e confirme verde.

- [ ] **Step 7: Commit**

```bash
git add frontend/javascript/wasm-player.js frontend/javascript/index.js \
        src/_partials/demos/_wasm.erb test/wasm_player_test.rb
git commit -m "Player do jogo 2D em WebAssembly

Carrega sob clique, cancela o menu de contexto (o botao direito pula),
e mostra o fim de jogo como HTML traduzido no lugar do texto que o GLUT
desenhava.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Estilos

Entrega: o casco comum às duas demos sai do `crt.css`, e a demo nova ganha estilo próprio no tema editorial.

**Files:**
- Create: `frontend/styles/demo.css`, `frontend/styles/wasm-demo.css`
- Modify: `frontend/styles/crt.css`, `frontend/styles/index.css`
- Test: `test/demo_styles_test.rb`, `test/crt_test.rb`

**Interfaces:**
- Consumes: as classes emitidas pelos dois partials.
- Produces: `demo.css` passa a ser dono de `.demo`, `.demo-frame`, `.demo-start`, `.demo-weight`, `.demo-error`, `.demo-instructions`, `.demo-license`. `crt.css` fica só com o que é CRT.

- [ ] **Step 1: Escopar o que é CRT antes de mover qualquer coisa**

**Faça isto primeiro.** Os dois partials emitem a classe `.demo-screen`. Hoje `crt.css` a estiliza sem escopo (proporção 4:3, fundo preto, borda, e as utilitárias do js-dos). Sem escopo, a demo nova herdaria o tratamento de CRT — que é justamente o que este trabalho não deve ter.

Em `frontend/styles/crt.css`, prefixe com `.demo-jsdos` toda regra cujo seletor comece em `.demo-screen`:

```css
/* Antes */
.demo-screen { aspect-ratio: 4 / 3; ... }
.demo-screen .some-jsdos-utility { ... }

/* Depois */
.demo-jsdos .demo-screen { aspect-ratio: 4 / 3; ... }
.demo-jsdos .demo-screen .some-jsdos-utility { ... }
```

A proporção 4:3 é do vídeo VGA do jogo DOS; este jogo é 1:1 por exigência do enunciado. Herdar 4:3 deformaria a arena.

- [ ] **Step 2: Extrair o casco comum**

Mova de `frontend/styles/crt.css` para um novo `frontend/styles/demo.css` as regras de `.demo`, `.demo-frame`, `.demo-start`, `.demo-weight`, `.demo-error`, `.demo-instructions` e `.demo-license`. Não mova nada de `.demo-screen` — ele acabou de virar CRT-específico no passo anterior. Abra o arquivo com:

```css
/* Casco comum as duas demos do site. O que e tratamento de CRT — fosforo,
   varredura, brilho, a proporcao 4:3 do VGA — fica em crt.css e vale so
   para a demo do jogo DOS. Este jogo aqui e OpenGL de 2024: fingir fosforo
   verde nele seria mentira estetica. */
```

- [ ] **Step 3: Escrever o estilo da demo nova**

`frontend/styles/wasm-demo.css`:

```css
/* O canvas tem 500x500 fixos por exigencia do enunciado do trabalho, e o
   jogo nao trata resize. Entao nao se estica: centraliza-se, e em telas
   estreitas encolhe proporcionalmente com o proprio aspecto quadrado. */
.demo-wasm .demo-screen {
  position: relative;
  max-width: 500px;
  margin-inline: auto;
}

.demo-wasm canvas {
  display: block;
  width: 100%;
  height: auto;
  aspect-ratio: 1 / 1;
  background: #000;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  image-rendering: pixelated;
}

/* A mensagem de fim de jogo. O C++ desenhava isto no centro da tela com
   fonte bitmap; aqui ela e HTML, entao herda o tipo e o idioma do site. */
.demo-wasm .demo-over {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--space);
  background: rgb(0 0 0 / 0.78);
  color: #ebe6dd;
  text-align: center;
  border-radius: var(--radius);
}

.demo-wasm .demo-over p {
  margin: 0;
  max-width: 28ch;
  font-family: var(--font-display);
  font-size: var(--titulo-2);
}

.demo-wasm .demo-over button {
  font: inherit;
  font-size: var(--texto-pequeno);
  padding: 0.5em 1.2em;
  color: #ebe6dd;
  background: transparent;
  border: 1px solid #9a9186;
  border-radius: var(--radius);
  cursor: pointer;
}

.demo-wasm .demo-over button:hover,
.demo-wasm .demo-over button:focus-visible {
  border-color: var(--accent);
}

.demo-wasm .demo-instructions {
  max-width: 32rem;
  margin-inline: auto;
}
```

O overlay tem fundo preto próprio, então as cores do texto são fixas em vez de virem dos tokens do tema — `#ebe6dd` sobre `rgb(0 0 0 / 0.78)` dá contraste bem acima de 4.5:1 nos dois temas, e um `var(--fg)` claro sobre esse fundo falharia no tema claro.

- [ ] **Step 4: Importar as folhas**

`frontend/styles/index.css`:

```css
@import "./tokens.css";
@import "./base.css";
@import "./components.css";
@import "./demo.css";
@import "./crt.css";
@import "./wasm-demo.css";
```

- [ ] **Step 5: Corrigir o teste do CRT**

Em `test/crt_test.rb`, o `test_every_class_the_demo_emits_has_styling` cobra do `crt.css` classes que agora vivem em `demo.css`. Reduza a lista às que continuam sendo CRT:

```ruby
  def test_every_class_the_demo_emits_has_styling
    %w[.demo-jsdos .demo-screen .demo-keypad
       .keypad-grid .keypad-marks .keypad-actions].each do |classe|
      assert_includes css, classe, "a classe #{classe} e emitida mas nao tem estilo"
    end
  end
```

- [ ] **Step 6: Escrever o teste das folhas de demo**

`test/demo_styles_test.rb`:

```ruby
require "test_helper"

class DemoStylesTest < Minitest::Test
  include OutputHelpers

  def demo_css
    ROOT.join("frontend/styles/demo.css").read
  end

  def wasm_css
    ROOT.join("frontend/styles/wasm-demo.css").read
  end

  def index_css
    ROOT.join("frontend/styles/index.css").read
  end

  def test_the_shared_shell_is_imported
    assert_includes index_css, "demo.css"
    assert_includes index_css, "wasm-demo.css"
  end

  def test_the_shared_shell_owns_the_common_classes
    %w[.demo-frame .demo-start .demo-weight .demo-error
       .demo-instructions .demo-license].each do |classe|
      assert_includes demo_css, classe,
        "#{classe} e comum as duas demos e deveria viver em demo.css"
    end
  end

  def test_the_wasm_demo_has_its_own_styling
    %w[.demo-wasm .demo-over].each do |classe|
      assert_includes wasm_css, classe, "a classe #{classe} e emitida mas nao tem estilo"
    end
  end

  # O jogo nao trata resize e o enunciado fixa a janela em 500x500. Esticar
  # o canvas alem disso deformaria a arena.
  def test_the_canvas_is_capped_at_the_size_the_game_expects
    assert_includes wasm_css, "500px"
    assert_includes wasm_css, "aspect-ratio"
  end

  # Este jogo nao e CRT. Fosforo verde nele seria mentira estetica.
  def test_the_wasm_demo_does_not_borrow_the_crt_treatment
    refute_includes wasm_css, "--crt-phosphor"
    refute_includes wasm_css, "--vga-green"
  end

  # Guarda de contraste, no molde de crt_test.rb. O overlay de fim de jogo
  # tem fundo preto proprio, entao suas cores sao fixas em vez de virem dos
  # tokens do tema -- e cor fixa e exatamente o que passa despercebido numa
  # revisao. Le os valores do arquivo, nao copiados aqui.
  def relative_luminance(hex)
    r, g, b = hex.delete("#").scan(/../).map { |c| c.to_i(16) / 255.0 }
    r, g, b = [r, g, b].map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
    (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
  end

  def contrast(a, b)
    la = relative_luminance(a)
    lb = relative_luminance(b)
    claro, escuro = [la, lb].max, [la, lb].min
    (claro + 0.05) / (escuro + 0.05)
  end

  def test_the_game_over_overlay_is_readable
    bloco = wasm_css[/\.demo-wasm\s+\.demo-over\s*\{(.*?)\}/m, 1]
    refute_nil bloco, "bloco .demo-wasm .demo-over nao encontrado"

    texto = bloco[/color:\s*(#[0-9a-fA-F]{6})/, 1]
    refute_nil texto, "a cor do texto do overlay nao foi encontrada"

    # O overlay cobre o canvas com preto a 78%; o pior caso de leitura e
    # sobre o preto puro do fundo do jogo.
    razao = contrast(texto, "#000000")
    assert razao >= 4.5,
      "o texto do overlay (#{texto}) tem contraste #{razao.round(2)}:1 sobre o " \
      "fundo escuro, abaixo do minimo 4.5:1 da WCAG para texto"
  end

  def test_the_restart_button_border_is_visible
    bloco = wasm_css[/\.demo-wasm\s+\.demo-over\s+button\s*\{(.*?)\}/m, 1]
    refute_nil bloco, "bloco do botao do overlay nao encontrado"

    borda = bloco[/border:\s*1px\s+solid\s+(#[0-9a-fA-F]{6})/, 1]
    refute_nil borda, "a cor da borda do botao nao foi encontrada"

    razao = contrast(borda, "#000000")
    assert razao >= 3.0,
      "a borda do botao (#{borda}) tem contraste #{razao.round(2)}:1, abaixo " \
      "do minimo 3:1 da WCAG para indicador nao textual"
  end

  # As folhas precisam chegar ao CSS publicado, nao so existir no fonte.
  # A build do esbuild ja publicou MISSING_ESBUILD_ASSET com a suite verde.
  def test_the_styles_reach_the_published_bundle
    publicado = Dir.glob(OUTPUT.join("_bridgetown/static/*.css")).first
    refute_nil publicado, "nenhum CSS publicado em output/_bridgetown/static/"

    conteudo = File.read(publicado)
    assert_includes conteudo, ".demo-wasm",
      "wasm-demo.css nao chegou ao bundle publicado"
  end
end
```

- [ ] **Step 7: Construir e rodar**

Run: `npm run esbuild && bin/bridgetown build && rake minitest`
Expected: PASS.

- [ ] **Step 8: Provar que os testes falham**

Remova a linha `@import "./wasm-demo.css";` do `index.css`:

Run: `npm run esbuild && bin/bridgetown build && rake minitest 2>&1 | tail -20`
Expected: FAIL em `test_the_shared_shell_is_imported` e `test_the_styles_reach_the_published_bundle`.

Desfaça e confirme verde.

- [ ] **Step 9: Commit**

```bash
git add frontend/styles/ test/demo_styles_test.rb test/crt_test.rb
git commit -m "Separa o casco comum das demos do tratamento de CRT

Com dois tipos de demo, .demo-frame e .demo-start morando no crt.css
obrigava a demo nova a herdar fosforo verde. O comum sai para demo.css;
crt.css fica com o que e CRT de verdade.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Conteúdo das páginas

Entrega: a página descreve o projeto nos dois idiomas. O README do upstream tem uma linha, então esta é a primeira descrição real que o trabalho ganha.

**Files:**
- Modify: `src/_projects/2d-graphics.en.md`, `src/_projects/2d-graphics.pt.md`
- Test: `test/projects_test.rb`

**Interfaces:**
- Consumes: o front matter da Task 6.
- Produces: nada.

- [ ] **Step 1: Escrever o corpo em português**

Substitua o `Corpo escrito na Task 9.` de `src/_projects/2d-graphics.pt.md` por (ajuste o texto ao que você julgar honesto, mantendo os fatos):

```markdown
O jogo lê a arena de um arquivo SVG: o retângulo azul é o campo, os
retângulos pretos são obstáculos, o círculo verde marca onde o jogador
começa e os vermelhos, os oponentes. Os círculos servem só de posição e
escala — cada personagem é desenhado inteiro a partir dali, com cabeça,
tronco, braço articulado e duas pernas com quadril e joelho, animadas ao
andar. O braço acompanha o mouse.

A arena tem nove telas de largura; a janela quadrada acompanha o jogador
na horizontal. O objetivo é atravessar da esquerda para a direita sem ser
atingido.

Toda a renderização usa OpenGL em modo imediato — `glBegin`, `glVertex2f`,
`glOrtho` — e o SVG é lido com [tinyxml2](https://github.com/leethomason/tinyxml2)
(licença zlib), compilado junto.

## O que custou trazer para o navegador

O Emscripten compila o C++ para WebAssembly, mas não implementa tudo que o
GLUT oferece. Duas coisas precisaram mudar.

`GL_POLYGON`, usado para desenhar os círculos, não existe na emulação de
modo imediato: o programa compilava e linkava sem reclamar, e abortava no
primeiro quadro. Trocado por `GL_TRIANGLE_FAN`, que desenha exatamente o
mesmo para um polígono convexo.

As mensagens de fim de jogo eram desenhadas com fontes bitmap do GLUT, que
o Emscripten também não tem. Elas viraram HTML sobre o canvas — o que, de
quebra, as deixou traduzidas.

Fora isso, o jogo aqui é o mesmo que roda nativo: os cerca de 180 KB de
WebAssembly desta página são o C++ do trabalho, compilado. Não há emulador
no meio.
```

- [ ] **Step 2: Escrever o corpo em inglês**

Substitua o `Corpo escrito na Task 9.` de `src/_projects/2d-graphics.en.md` por:

```markdown
The game reads its arena from an SVG file: the blue rectangle is the field,
black rectangles are obstacles, the green circle marks where the player
starts and the red ones mark the opponents. The circles only carry position
and scale — each character is drawn from scratch around them, with a head,
a torso, an articulated arm and two legs hinged at hip and knee, animated
as they walk. The arm follows the mouse.

The arena is nine screens wide; the square window tracks the player
horizontally. The goal is to cross from left to right without being hit.

All rendering uses immediate-mode OpenGL — `glBegin`, `glVertex2f`,
`glOrtho` — and the SVG is parsed with
[tinyxml2](https://github.com/leethomason/tinyxml2) (zlib licence),
compiled in.

## What it cost to bring here

Emscripten compiles the C++ to WebAssembly, but it does not implement
everything GLUT offers. Two things had to change.

`GL_POLYGON`, used to draw the circles, does not exist in its immediate-mode
emulation: the program compiled and linked without complaint, then aborted
on the first frame. Swapped for `GL_TRIANGLE_FAN`, which draws exactly the
same thing for a convex polygon.

The end-of-game messages were drawn with GLUT bitmap fonts, which Emscripten
also lacks. They became HTML over the canvas — which, as a side effect, got
them translated.

Beyond that, the game here is the one that runs natively: the roughly 180 KB
of WebAssembly on this page are the project's own C++, compiled. There is no
emulator in between.
```

- [ ] **Step 3: Verificar que as duas páginas existem e se ligam**

Run: `bin/bridgetown build && rake minitest && rake proof`
Expected: PASS, incluindo o html-proofer (o link para o tinyxml2 é externo e não é checado; os internos são).

- [ ] **Step 4: Commit**

```bash
git add src/_projects/2d-graphics.en.md src/_projects/2d-graphics.pt.md
git commit -m "Corpo das paginas do projeto 2D

O README do upstream tem uma linha, entao esta e a primeira descricao
real que o trabalho ganha.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Verificação fim a fim

Entrega: a demo é verificada na página de verdade, não só na bancada, e a suíte inteira fecha verde.

**Files:**
- Modify: `Rakefile`, `build/2d/verify.js`
- Test: todos

**Interfaces:**
- Consumes: tudo das tarefas anteriores.
- Produces: `rake demo2d:verify:site`.

- [ ] **Step 1: Ensinar o driver a clicar no botão**

A página do site nasce com a demo desligada — é preciso clicar antes de qualquer coisa. Em `build/2d/verify.js`, logo depois do `page.goto`, acrescente:

```javascript
  // Na pagina do site a demo carrega sob clique; na bancada ela ja sobe
  // sozinha. Clicar se houver botao cobre os dois casos com um script so.
  const comecar = page.locator("[data-wasm-start]")
  if (await comecar.count()) {
    await comecar.click()
    await page.waitForSelector("[data-wasm-canvas]", { state: "visible", timeout: 30000 })
  }
```

E troque o seletor fixo `#canvas` por um que sirva aos dois alvos, no topo do arquivo:

```javascript
const CANVAS = process.env.CANVAS || "#canvas"
```

Substitua cada `"#canvas"` restante por `CANVAS`.

A espera por `window.__modulo` também precisa cair: esse objeto é da bancada, e o player do site não expõe o módulo — nem deve, só para facilitar teste. Troque por uma espera que vale nos dois:

```javascript
  // O canvas so ganha tamanho depois que o modulo sobe e o GLUT cria a
  // janela. Serve para a bancada e para a pagina do site.
  await page.waitForFunction(
    (sel) => {
      const c = document.querySelector(sel)
      return c && c.width > 0 && c.clientWidth > 0
    },
    CANVAS,
    { timeout: 60000 }
  )
```

Pela mesma razão, a conferência do reinício (acrescentada na Task 3) não pode chamar `ccall` direto. Troque-a por uma que use o botão quando ele existir:

```javascript
  const botaoDnovo = page.locator("[data-wasm-restart]")
  if (await botaoDnovo.count()) {
    await botaoDnovo.click()
  } else {
    await page.evaluate(() => window.__modulo.ccall("reiniciarDoNavegador", null, [], []))
  }
  await page.waitForTimeout(600)
  const depoisDoReinicio = await alturaDoHeroi(page)
  confere("reiniciar devolve o jogo", depoisDoReinicio !== null)
```

Na página do site isso passa a verificar o caminho de verdade — o botão que o visitante clica — em vez de uma porta dos fundos.

Por fim, a conferência do fim de jogo lê `window.__fim`, que também só existe na bancada. No site, o sinal equivalente é o overlay ficar visível:

```javascript
  await page.keyboard.press(".")
  await page.waitForTimeout(600)
  const overlay = page.locator("[data-wasm-over]")
  if (await overlay.count()) {
    confere("o overlay de fim de jogo aparece", await overlay.isVisible())
    const texto = await overlay.locator("[data-wasm-over-message]").textContent()
    confere("o overlay traz uma mensagem", texto.trim().length > 0)
  } else {
    confere("o fim de jogo avisa a pagina com vitoria",
            (await page.evaluate(() => window.__fim)) === 1)
  }
```

- [ ] **Step 2: Acrescentar a task do site**

Dentro de `namespace :demo2d do`:

```ruby
  namespace :verify do
    desc "Verifica a demo na pagina do site de verdade (exige Docker e output/)"
    task :site do
      require "fileutils"

      saida = File.expand_path("output")
      receita = File.expand_path("build/2d")

      unless File.directory?(saida)
        raise "output/ nao existe — rode `bin/bridgetown build` primeiro."
      end

      FileUtils.cp("#{receita}/verify.js", saida)

      begin
        sh "docker run --rm --network host " \
           "--user #{Process.uid}:#{Process.gid} " \
           "-v #{saida}:/work -w /work " \
           "-e ALVO=http://localhost:4124/projects/2d-graphics/ " \
           "-e CANVAS=[data-wasm-canvas] " \
           "#{IMAGEM_PLAYWRIGHT} " \
           "bash -c 'npm install --silent playwright@1.56.0 && " \
           "(python3 -m http.server 4124 &) && sleep 2 && node verify.js'"
      ensure
        FileUtils.rm_f("#{saida}/verify.js")
      end
    end
  end
```

- [ ] **Step 3: Rodar a verificação na página de verdade**

Run: `rake check && rake demo2d:verify:site`
Expected: `rake check` verde, e todas as linhas do verificador `ok`. Este é o momento em que se sabe que a demo funciona onde ela vai viver — botão, canvas, controles, overlay e reinício.

- [ ] **Step 4: Conferir que a suíte inteira está verde**

Run: `rake check`
Expected: PASS, sem falhas nem erros. Anote a contagem de testes e asserções.

- [ ] **Step 5: Verificação humana**

Run: `bin/bridgetown start`

Abra `http://localhost:4000/projects/2d-graphics/` e confirme com os próprios olhos:
- o botão de jogar aparece e nada foi baixado antes do clique (aba Network)
- nenhuma requisição sai da nossa origem
- o jogo desenha e responde a `A`, `D`, `W`, mouse e botão direito
- o botão direito **não** abre o menu do navegador
- `ESC` não mata a demo
- ao chegar na direita da arena (ou apertar `.`), o overlay aparece traduzido
- "jogar de novo" devolve o jogo
- a página em português mostra tudo traduzido

- [ ] **Step 6: Commit**

```bash
git add Rakefile build/2d/verify.js
git commit -m "Verificacao da demo 2D na pagina do site

A bancada prova os artefatos; esta prova a pagina, com o botao de carregar
sob clique no caminho. Mesmo script, alvo diferente.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Notas para quem executar

**Sobre o que este plano assume verificado.** O probe que originou a spec compilou e rodou este jogo em Chromium de verdade. As flags do `em++`, o `Module.arguments` levando o SVG a `argv[1]`, o `GL_TRIANGLE_FAN`, a supressão do menu de contexto e as medidas de altura do pulo foram todos observados, não deduzidos. O que **não** foi verificado é o `-sMODULARIZE` — por isso ele entra logo na Task 1, e o teste `test_the_module_is_a_factory_named_criarJogo2D` existe para cobrá-lo.

**Sobre a armadilha central.** Compilar e linkar não prova nada aqui. A primeira compilação deste port fechou limpa e o jogo abortava no primeiro quadro. Se você mudar qualquer coisa no C++ ou nas flags, rode `rake demo2d:verify` — é o único instrumento que enxerga esse tipo de falha.

**Sobre os patches.** Os diffs neste plano mostram a intenção e os comentários que devem sobreviver. Gere os arquivos de verdade com `git diff` sobre um clone no SHA fixo, para o contexto bater exatamente. Um patch que não aplica derruba a build de propósito.

**Sobre medir o canvas.** Nunca use `readPixels` para saber se o jogo desenhou: o drawing buffer do WebGL não é preservado depois da composição e a leitura volta preta, sugerindo falha onde não há. O caminho correto está em `alturaDoHeroi`: screenshot → `<img>` → canvas 2D → `getImageData`.
