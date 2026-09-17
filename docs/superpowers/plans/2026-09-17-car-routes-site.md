# Projeto car-routes no site — Plano de Implementação (2 de 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publicar a página do projeto `car-routes` com o texto didático sobre Dijkstra replanejado e players que rodam o C original em WebAssembly, incluindo um editor de trânsito.

**Architecture:** Uma receita Docker compila o upstream (SHA fixo, já com o modo trace do plano 1) para `rotas.js`/`rotas.wasm`, versionados em `src/demos/car-routes/`. Um tipo de demo `routes` entra no dispatcher com partial, folha de estilo e cinco módulos JS pequenos: entrada (JSON → texto do C), wasm (carrega e roda), trace (parse e redução de estado), desenho (canvas) e player (DOM, relógio, editor). Cenários vivem num JSON com coordenadas. Testes em três camadas: Ruby sobre o output, `node --test` sobre os módulos puros, Playwright em Docker sobre a página real.

**Tech Stack:** Emscripten 6.0.8 em Docker, Bridgetown 2.2.2, ERB, esbuild, JavaScript ES2022 (módulos), Canvas 2D, Ruby/Minitest, `node --test`, Playwright em Docker, Rake.

**Spec:** `docs/superpowers/specs/2026-09-17-car-routes-design.md`, Seções 2–5.

**Pré-requisito:** o plano 1 (`2026-09-17-car-routes-upstream.md`) executado e o PR `trace-mode` aberto; o SHA da ponta da branch (ou do merge) é o `SHA_ROUTES` da Task 1.

## Global Constraints

- **Node 22** (`.nvmrc`); no shell: `export PATH="$HOME/.nvm/versions/node/v22.23.2/bin:$PATH"`.
- **Worktree:** `.claude/worktrees/car-routes`, branch `car-routes`. Rodar tudo de lá.
- **Upstream fixado** em `REPO_ROUTES = "https://github.com/viniciuscole/car-routes-optimazing"` e `SHA_ROUTES` (constante no Rakefile). Nunca clonar `main` sem SHA.
- **`docker run` sempre com `--user #{Process.uid}:#{Process.gid}`.**
- **Artefatos são commitados; `routes:build` e `routes:verify` ficam fora do `rake check`.**
- **Identificadores e textos de código em português** (padrão do JS do site: `iniciar`, `mostrarFalha`). Mensagens de commit em português, sem acentos.
- **Comentários só em hacks** — coisas impossíveis de entender sem o comentário. O resto se explica.
- **Todo teste novo é provado por remoção**: apagar o que ele guarda e ver a suíte ficar vermelha.
- **Todo `t("...")` novo em partial precisa existir em `pt.yml` e `en.yml`** (`locales_test.rb` cobra paridade de chaves).
- **Cores no canvas vêm dos tokens** (`--bg`, `--fg`, `--muted`, `--accent`, `--border`) lidos por `getComputedStyle` a cada frame. Nenhum hex fixo no JS.
- **`rake check` verde ao fim de cada task** que toca em Ruby/ERB/output; `node --test` verde ao fim de cada task que toca em JS puro.

## Estrutura de arquivos

| arquivo | ação | responsabilidade |
|---|---|---|
| `build/routes/Dockerfile`, `build/routes/build.sh` | criar | compila o upstream para WASM |
| `build/routes/verify.js` | criar | verificação em navegador (Playwright) |
| `Rakefile` | modificar | `routes:build`, `routes:verify`, `jstest` no `check` |
| `src/demos/car-routes/rotas.js`, `rotas.wasm` | gerar e commitar | o C compilado |
| `src/demos/car-routes/cenarios.json` | criar | os quatro cenários com coordenadas |
| `plugins/builders/demo_helper.rb` | modificar | `routes` em `DEMO_TYPES` |
| `src/_partials/demos/_routes.erb` | criar | player principal com editor e os textos |
| `src/_locales/pt.yml`, `en.yml` | modificar | `demo.routes.*` |
| `frontend/styles/routes-demo.css`, `index.css` | criar/modificar | estilo dos players |
| `frontend/javascript/routes-entrada.js` | criar | `gerarEntrada(cenario)` |
| `frontend/javascript/routes-trace.js` | criar | `analisar(texto)`, `estadoInicial`, `reduzir` |
| `frontend/javascript/routes-wasm.js` | criar | `carregar(base)`, `rodar(entrada)` |
| `frontend/javascript/routes-desenho.js` | criar | `desenhar(ctx, cenario, estado, progresso, tema, largura, altura)` |
| `frontend/javascript/routes-player.js` | criar | monta players, relógio, controles, editor |
| `frontend/javascript/index.js` | modificar | importa `routes-player.js` |
| `test/js/*.test.mjs` | criar | testes `node --test` dos módulos puros |
| `test/routes_*.rb` | criar | testes Ruby |
| `src/_projects/car-routes.pt.md`, `.en.md` | criar | a página |

---

### Task 1: Receita de build e artefatos

**Files:**
- Create: `build/routes/Dockerfile`, `build/routes/build.sh`, `test/routes_artifacts_test.rb`
- Modify: `Rakefile` (novo `namespace :routes`)
- Generate: `src/demos/car-routes/rotas.js`, `src/demos/car-routes/rotas.wasm`

**Interfaces:**
- Produces: `/demos/car-routes/rotas.js` que define a factory global `criarRotas(opcoes) → Promise<Module>`, com `Module.ccall("run_trace", "number", ["string"], [entrada])` e saída pelo `opcoes.print(linha)`.

- [ ] **Step 1: Teste de artefatos** — `test/routes_artifacts_test.rb`:

```ruby
require "test_helper"

class RoutesArtifactsTest < Minitest::Test
  include OutputHelpers

  BASE = "demos/car-routes".freeze
  MINIMO_WASM = 20_000
  MINIMO_JS   = 20_000

  def test_the_two_artefacts_are_versioned_in_the_repository
    %w[rotas.js rotas.wasm].each do |nome|
      assert ROOT.join("src", BASE, nome).file?, "faltou src/#{BASE}/#{nome} — rode `rake routes:build`"
    end
  end

  def test_the_two_artefacts_are_published
    %w[rotas.js rotas.wasm].each do |nome|
      assert output("#{BASE}/#{nome}").file?, "#{nome} existe em src/ mas nao chegou em output/"
    end
  end

  def test_the_artefacts_are_not_truncated
    assert_operator output("#{BASE}/rotas.wasm").size, :>=, MINIMO_WASM
    assert_operator output("#{BASE}/rotas.js").size, :>=, MINIMO_JS
  end

  def test_the_loader_exports_run_trace
    js = output("#{BASE}/rotas.js").read
    assert_includes js, "criarRotas", "o loader nao define a factory criarRotas"
    assert_includes js, "_run_trace", "run_trace nao foi exportada"
  end
end
```

- [ ] **Step 2: Rodar** `bundle exec ruby -Itest test/routes_artifacts_test.rb` → 4 falhas (artefatos ausentes).

- [ ] **Step 3: `build/routes/Dockerfile`**

```dockerfile
FROM emscripten/emsdk:6.0.8

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

COPY build.sh /usr/local/bin/build-routes
RUN chmod +x /usr/local/bin/build-routes

ENTRYPOINT ["/usr/local/bin/build-routes"]
```

- [ ] **Step 4: `build/routes/build.sh`**

```bash
#!/bin/bash
set -euo pipefail
cd /src

if [ "$(git rev-parse HEAD)" != "$SHA_ESPERADO" ]; then
  echo "ERRO: /src esta em $(git rev-parse HEAD), esperado $SHA_ESPERADO" >&2
  exit 1
fi

emcc -std=gnu99 -Os \
  src/PQ.c src/adjacency.c src/algorithm.c src/edge.c src/updates.c src/util.c src/route.c src/trace.c \
  -sMODULARIZE=1 \
  -sEXPORT_NAME=criarRotas \
  -sEXPORTED_FUNCTIONS='["_run_trace"]' \
  -sEXPORTED_RUNTIME_METHODS='["ccall"]' \
  -sALLOW_MEMORY_GROWTH=0 \
  -sEXIT_RUNTIME=0 \
  -o /out/rotas.js

ls -l /out/
```

- [ ] **Step 5: Rakefile** — após o `namespace :demo2d`:

```ruby
namespace :routes do
  REPO_ROUTES = "https://github.com/viniciuscole/car-routes-optimazing".freeze
  SHA_ROUTES  = "<SHA da ponta de trace-mode, registrado no plano 1 Task 7>".freeze

  desc "Reconstroi o simulador de rotas em WebAssembly a partir do fonte (exige Docker)"
  task :build do
    require "fileutils"
    require "tmpdir"

    destino = File.expand_path("src/demos/car-routes")
    receita = File.expand_path("build/routes")
    FileUtils.mkdir_p(destino)

    Dir.mktmpdir do |tmp|
      fonte = "#{tmp}/routes"
      sh "git clone #{REPO_ROUTES} #{fonte}"
      sh "git -C #{fonte} checkout --detach #{SHA_ROUTES}"
      sh "docker build -t viniciuscole-routes-build #{receita}"
      sh "docker run --rm " \
         "--user #{Process.uid}:#{Process.gid} " \
         "-e SHA_ESPERADO=#{SHA_ROUTES} " \
         "-v #{fonte}:/src " \
         "-v #{destino}:/out " \
         "viniciuscole-routes-build"
    end
  end
end
```
Substituir o texto entre `<>` pelo SHA real (40 hex).

- [ ] **Step 6: Rodar** `bundle exec rake routes:build` → `ls -l src/demos/car-routes/` mostra `rotas.js` e `rotas.wasm` (esperado: 30–50 KB cada com `-Os`).

- [ ] **Step 7: Provar no Node que o módulo roda** (não é teste permanente; a Task 5 faz o permanente):

```bash
node -e '
const criar = require("./src/demos/car-routes/rotas.js");
const entrada = "6;9\n1;6\n60\n1;2;1000\n1;3;1500\n2;4;1000\n3;4;800\n2;5;2500\n4;6;1000\n5;6;500\n3;5;3000\n4;5;600\n30;2;4;5\n";
criar({ print: l => console.log(l) }).then(m => m.ccall("run_trace","number",["string"],[entrada]));
'
```
Esperado: o trace da spec, terminando em `done 240.000 4.000`.

- [ ] **Step 8: `rake check`** → verde (o teste novo passa; os antigos seguem).

- [ ] **Step 9: Commit**

```bash
git add build/routes Rakefile src/demos/car-routes test/routes_artifacts_test.rb
git commit -m "Compila o car-routes-optimazing para WebAssembly"
```

---

### Task 2: Tipo de demo `routes` — dispatcher, partial, locale, CSS

**Files:**
- Modify: `plugins/builders/demo_helper.rb:5`, `src/_locales/pt.yml`, `src/_locales/en.yml`, `frontend/styles/index.css`, `test/demo_dispatcher_test.rb`
- Create: `src/_partials/demos/_routes.erb`, `frontend/styles/routes-demo.css`, `test/routes_partial_test.rb`, `src/_projects/car-routes.pt.md`, `src/_projects/car-routes.en.md` (versão mínima; o texto vem na Task 9)

**Interfaces:**
- Produces: o markup que `routes-player.js` (Task 7) monta. Ganchos: `data-rotas` (id do cenário), `data-rotas-editor` (presente só no principal), `data-rotas-base` (`/demos/car-routes`), `data-rotas-textos` (JSON com os textos), `data-rotas-canvas`, `data-rotas-controles`, `data-rotas-painel`, `data-rotas-erro`.

- [ ] **Step 1: Testes** — em `test/demo_dispatcher_test.rb` acrescentar:

```ruby
  def test_routes_is_a_known_demo_type
    assert_includes ALLOWED_TYPES, "routes"
  end
```

`test/routes_partial_test.rb`:

```ruby
require "test_helper"

class RoutesPartialTest < Minitest::Test
  include OutputHelpers

  EN = "projects/car-routes/index.html".freeze
  PT = "pt/projects/car-routes/index.html".freeze

  def test_the_project_page_renders_the_routes_demo
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      assert_includes corpo, 'class="demo demo-routes"', "#{pagina} nao renderizou a demo routes"
      refute_includes corpo, 'class="demo demo-none"'
    end
  end

  def test_the_hooks_the_player_depends_on_exist
    corpo = page_body(EN)
    %w[data-rotas="engarrafamento" data-rotas-editor data-rotas-base="/demos/car-routes"
       data-rotas-textos data-rotas-canvas data-rotas-controles data-rotas-painel data-rotas-erro].each do |gancho|
      assert_includes corpo, gancho, "faltou o gancho #{gancho}"
    end
  end

  def test_the_texts_are_valid_json_in_both_locales
    require "json"
    [EN, PT].each do |pagina|
      bruto = page_body(pagina)[/data-rotas-textos="([^"]+)"/, 1]
      refute_nil bruto, "#{pagina} sem data-rotas-textos"
      textos = JSON.parse(CGI.unescapeHTML(bruto))
      %w[play pause step speed restart clock queue km apply run reset remove instant kmh].each do |chave|
        assert textos.key?(chave), "#{pagina}: falta o texto #{chave}"
      end
    end
  end
end
```
(`require "cgi"` no topo.)

- [ ] **Step 2: Rodar** os dois arquivos de teste → falham (tipo desconhecido; página inexistente).

- [ ] **Step 3: Dispatcher** — `DEMO_TYPES = %w[none jsdos wasm video routes].freeze`.

- [ ] **Step 4: Locale** — em `pt.yml`, dentro de `demo:`:

```yaml
    routes:
      label: "Simulação interativa"
      weight: "Carrega o simulador em WebAssembly, cerca de 80 KB."
      textos:
        play: "Rodar"
        pause: "Pausar"
        step: "Passo"
        speed: "Velocidade"
        restart: "Reiniciar"
        clock: "Relógio"
        queue: "Fila de prioridade"
        km: "km"
        apply: "Aplicar"
        run: "Rodar de novo"
        reset: "Restaurar cenário"
        remove: "remover"
        instant: "Instante (s)"
        kmh: "Nova velocidade (km/h)"
        editor_hint: "Clique numa via para mudar a velocidade dela num instante."
        unreachable: "O destino ficou inalcançável."
        legend_open: "na fila"
        legend_closed: "fechado"
        legend_planned: "planejado"
        legend_driven: "percorrido"
```

Em `en.yml` as mesmas chaves: `label: "Interactive simulation"`, `weight: "Loads the WebAssembly simulator, about 80 KB."`, `play: "Run"`, `pause: "Pause"`, `step: "Step"`, `speed: "Speed"`, `restart: "Restart"`, `clock: "Clock"`, `queue: "Priority queue"`, `km: "km"`, `apply: "Apply"`, `run: "Run again"`, `reset: "Reset scenario"`, `remove: "remove"`, `instant: "Instant (s)"`, `kmh: "New speed (km/h)"`, `editor_hint: "Click a road to change its speed at a given instant."`, `unreachable: "The destination became unreachable."`, `legend_open: "in queue"`, `legend_closed: "closed"`, `legend_planned: "planned"`, `legend_driven: "driven"`.

- [ ] **Step 5: Partial** `src/_partials/demos/_routes.erb`:

```erb
<% textos = %w[play pause step speed restart clock queue km apply run reset remove instant kmh editor_hint unreachable legend_open legend_closed legend_planned legend_driven]
     .to_h { |chave| [chave, t("demo.routes.textos.#{chave}")] } %>
<section class="demo demo-routes" aria-label="<%= t("demo.routes.label") %>">
  <div class="rotas"
       data-rotas="engarrafamento"
       data-rotas-editor
       data-rotas-base="/demos/car-routes"
       data-rotas-textos="<%= textos.to_json.gsub('"', '&quot;') %>">
    <canvas data-rotas-canvas></canvas>
    <div class="rotas-controles" data-rotas-controles></div>
    <aside class="rotas-painel" data-rotas-painel></aside>
    <p class="demo-weight"><%= t("demo.routes.weight") %></p>
    <p class="demo-error" data-rotas-erro hidden>
      <%= t("demo.failed") %>
      <a href="<%= resource.data.repo %>"><%= resource.data.repo.to_s.sub("https://", "") %></a>
    </p>
    <noscript>
      <p class="demo-weight">
        <%= t("demo.noscript") %>
        <a href="<%= resource.data.repo %>"><%= resource.data.repo.to_s.sub("https://", "") %></a>
      </p>
    </noscript>
  </div>
</section>
```
Se `t("demo.routes.textos.play")` com chave interpolada não for pego pelo `locales_test` (ele varre `t("literal")`), tudo bem: o `routes_partial_test` Step 1 cobra as chaves no HTML gerado.

- [ ] **Step 6: Páginas mínimas** — `src/_projects/car-routes.pt.md`:

```yaml
---
title: Rotas com trânsito em C
locale: pt
slug: car-routes
year: 2023
featured: true
order: 4
summary: Caminho mais rápido num mapa cujo trânsito muda enquanto o carro anda — Dijkstra com fila de prioridade, replanejado a cada atualização, rodando aqui compilado para WebAssembly.
tech: [C, Dijkstra, Emscripten, WebAssembly]
repo: https://github.com/viniciuscole/car-routes-optimazing
demo:
  type: routes
---

Texto em construção.
```
`car-routes.en.md`: `title: Routes under changing traffic, in C`, `locale: en`, `summary: Fastest path on a map whose traffic changes while the car is moving — Dijkstra with a priority queue, re-planned at every update, running here compiled to WebAssembly.`, resto igual, corpo `Text under construction.`

- [ ] **Step 7: CSS** — `frontend/styles/routes-demo.css` e `@import "./routes-demo.css";` em `index.css`:

```css
.rotas {
  display: grid;
  gap: var(--space);
  grid-template-columns: minmax(0, 1fr);
}

.rotas canvas {
  aspect-ratio: 3 / 2;
  background: var(--bg-sutil);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  display: block;
  width: 100%;
}

.rotas-controles {
  align-items: center;
  display: flex;
  flex-wrap: wrap;
  font-family: var(--font-mono);
  font-size: var(--texto-meta);
  gap: 0.5rem;
}

.rotas-controles button,
.rotas-editor button {
  background: none;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--fg);
  cursor: pointer;
  font: inherit;
  padding: 0.25rem 0.6rem;
}

.rotas-controles button[aria-pressed="true"] { border-color: var(--accent); color: var(--accent); }
.rotas-controles button:disabled { color: var(--muted); cursor: default; }

.rotas-painel {
  display: grid;
  font-family: var(--font-mono);
  font-size: var(--texto-meta);
  gap: 0.25rem;
  grid-template-columns: repeat(auto-fit, minmax(10rem, 1fr));
}

.rotas-painel dt { color: var(--muted); }
.rotas-painel dd { margin: 0; }
.rotas-fila { display: flex; flex-wrap: wrap; gap: 0.25rem 0.75rem; }

.rotas-legenda { color: var(--muted); display: flex; flex-wrap: wrap; gap: 0.25rem 1rem; }
.rotas-legenda span::before {
  border-radius: 50%;
  content: "";
  display: inline-block;
  height: 0.6em;
  margin-right: 0.3em;
  width: 0.6em;
}
.rotas-legenda .aberto::before { border: 2px solid var(--accent); }
.rotas-legenda .fechado::before { background: var(--muted); }
.rotas-legenda .planejado::before { border-bottom: 2px dashed var(--accent); border-radius: 0; height: 0; }
.rotas-legenda .percorrido::before { border-bottom: 2px solid var(--fg); border-radius: 0; height: 0; }

.rotas-editor {
  align-items: end;
  display: flex;
  flex-wrap: wrap;
  font-family: var(--font-mono);
  font-size: var(--texto-meta);
  gap: 0.5rem;
}
.rotas-editor label { display: grid; gap: 0.15rem; }
.rotas-editor input { font: inherit; padding: 0.2rem 0.4rem; width: 7rem; }
.rotas-editor ul { list-style: none; margin: 0; padding: 0; width: 100%; }
.rotas-editor li { display: flex; gap: 0.5rem; }
.rotas-editor .rotas-erro { color: var(--accent); width: 100%; }

.project-body .rotas { margin-block: calc(var(--space) * 2); }
```

- [ ] **Step 8: `rake check`** → verde (inclui `proof`: o link do repo é externo, ignorado).

- [ ] **Step 9: Commit**

```bash
git add plugins/builders/demo_helper.rb src/_partials/demos/_routes.erb src/_locales frontend/styles src/_projects/car-routes.*.md test/demo_dispatcher_test.rb test/routes_partial_test.rb
git commit -m "Adiciona o tipo de demo routes com partial, textos e estilo"
```

---

### Task 3: Cenários e geração da entrada do C

**Files:**
- Create: `src/demos/car-routes/cenarios.json`, `frontend/javascript/routes-entrada.js`, `test/js/routes-entrada.test.mjs`, `test/routes_scenarios_test.rb`
- Modify: `Rakefile` (`task :jstest`, incluído em `check`), `package.json` (`"test": "node --test test/js/"`)

**Interfaces:**
- Produces: `gerarEntrada(cenario) → string` (formato do C, termina em `\n`); `chaveAresta(de, para) → "de-para"`. Formato de cenário:
  `{ nos: [{id, x, y}], arestas: [{de, para, m}], origem, destino, kmh, atualizacoes: [{t, de, para, kmh}] }`.

- [ ] **Step 1: Infra de teste JS** — `package.json` ganha `"test": "node --test test/js/"` em `scripts`. Rakefile:

```ruby
desc "Roda os testes dos modulos JavaScript puros"
task :jstest do
  sh "npm test"
end
```
e em `task :check`, após `Rake::Task["minitest"].invoke`: `Rake::Task["jstest"].invoke`.

- [ ] **Step 2: Teste** `test/js/routes-entrada.test.mjs`:

```js
import { test } from "node:test"
import assert from "node:assert/strict"
import { gerarEntrada, chaveAresta } from "../../frontend/javascript/routes-entrada.js"

const cenario = {
  nos: [{ id: 1, x: 0, y: 0 }, { id: 2, x: 1, y: 0 }, { id: 3, x: 1, y: 1 }],
  arestas: [{ de: 1, para: 2, m: 1000 }, { de: 2, para: 3, m: 500 }],
  origem: 1, destino: 3, kmh: 60,
  atualizacoes: [{ t: 30, de: 2, para: 3, kmh: 5 }],
}

test("gera o formato do trabalho", () => {
  assert.equal(gerarEntrada(cenario), "3;2\n1;3\n60\n1;2;1000\n2;3;500\n30;2;3;5\n")
})

test("sem atualizacoes termina apos as arestas", () => {
  assert.equal(gerarEntrada({ ...cenario, atualizacoes: [] }), "3;2\n1;3\n60\n1;2;1000\n2;3;500\n")
})

test("ordena as atualizacoes por instante", () => {
  const dois = { ...cenario, atualizacoes: [{ t: 90, de: 1, para: 2, kmh: 10 }, { t: 30, de: 2, para: 3, kmh: 5 }] }
  assert.match(gerarEntrada(dois), /30;2;3;5\n90;1;2;10\n$/)
})

test("chaveAresta", () => {
  assert.equal(chaveAresta(2, 3), "2-3")
})
```

- [ ] **Step 3: Rodar** `npm test` → falha (módulo inexistente).

- [ ] **Step 4: Módulo** `frontend/javascript/routes-entrada.js`:

```js
export function chaveAresta(de, para) {
  return `${de}-${para}`
}

export function gerarEntrada(cenario) {
  const linhas = [
    `${cenario.nos.length};${cenario.arestas.length}`,
    `${cenario.origem};${cenario.destino}`,
    `${cenario.kmh}`,
    ...cenario.arestas.map((a) => `${a.de};${a.para};${a.m}`),
    ...[...cenario.atualizacoes].sort((a, b) => a.t - b.t).map((u) => `${u.t};${u.de};${u.para};${u.kmh}`),
  ]
  return linhas.join("\n") + "\n"
}
```

- [ ] **Step 5: Rodar** `npm test` → 4 passam.

- [ ] **Step 6: Cenários** `src/demos/car-routes/cenarios.json`. Coordenadas em [0,1]; ids de 1 a N. Distâncias em metros escolhidas para os tempos saírem "redondos" a 60 km/h (1000 m = 60 s).

```json
{
  "dijkstra": {
    "nos": [
      { "id": 1, "x": 0.08, "y": 0.2 }, { "id": 2, "x": 0.36, "y": 0.2 }, { "id": 3, "x": 0.64, "y": 0.2 }, { "id": 4, "x": 0.92, "y": 0.2 },
      { "id": 5, "x": 0.08, "y": 0.5 }, { "id": 6, "x": 0.36, "y": 0.5 }, { "id": 7, "x": 0.64, "y": 0.5 }, { "id": 8, "x": 0.92, "y": 0.5 },
      { "id": 9, "x": 0.08, "y": 0.8 }, { "id": 10, "x": 0.36, "y": 0.8 }, { "id": 11, "x": 0.64, "y": 0.8 }, { "id": 12, "x": 0.92, "y": 0.8 }
    ],
    "arestas": [
      { "de": 1, "para": 2, "m": 1000 }, { "de": 2, "para": 3, "m": 1000 }, { "de": 3, "para": 4, "m": 1000 },
      { "de": 5, "para": 6, "m": 800 }, { "de": 6, "para": 7, "m": 800 }, { "de": 7, "para": 8, "m": 800 },
      { "de": 9, "para": 10, "m": 1200 }, { "de": 10, "para": 11, "m": 1200 }, { "de": 11, "para": 12, "m": 1200 },
      { "de": 1, "para": 5, "m": 700 }, { "de": 5, "para": 9, "m": 700 },
      { "de": 2, "para": 6, "m": 700 }, { "de": 6, "para": 10, "m": 700 },
      { "de": 3, "para": 7, "m": 700 }, { "de": 7, "para": 11, "m": 700 },
      { "de": 4, "para": 8, "m": 700 }, { "de": 8, "para": 12, "m": 700 },
      { "de": 6, "para": 2, "m": 700 }, { "de": 7, "para": 3, "m": 700 }
    ],
    "origem": 1, "destino": 12, "kmh": 60, "atualizacoes": []
  },
  "engarrafamento": {
    "nos": [
      { "id": 1, "x": 0.08, "y": 0.5 }, { "id": 2, "x": 0.32, "y": 0.28 }, { "id": 3, "x": 0.32, "y": 0.74 },
      { "id": 4, "x": 0.62, "y": 0.28 }, { "id": 5, "x": 0.62, "y": 0.74 }, { "id": 6, "x": 0.92, "y": 0.5 }
    ],
    "arestas": [
      { "de": 1, "para": 2, "m": 1000 }, { "de": 1, "para": 3, "m": 1500 }, { "de": 2, "para": 4, "m": 1000 },
      { "de": 2, "para": 5, "m": 2500 }, { "de": 3, "para": 4, "m": 800 }, { "de": 3, "para": 5, "m": 3000 },
      { "de": 4, "para": 6, "m": 1000 }, { "de": 4, "para": 5, "m": 600 }, { "de": 5, "para": 6, "m": 500 }
    ],
    "origem": 1, "destino": 6, "kmh": 60,
    "atualizacoes": [{ "t": 30, "de": 2, "para": 4, "kmh": 5 }]
  },
  "tarde-demais": {
    "nos": [
      { "id": 1, "x": 0.08, "y": 0.5 }, { "id": 2, "x": 0.32, "y": 0.28 }, { "id": 3, "x": 0.32, "y": 0.74 },
      { "id": 4, "x": 0.62, "y": 0.28 }, { "id": 5, "x": 0.62, "y": 0.74 }, { "id": 6, "x": 0.92, "y": 0.5 }
    ],
    "arestas": [
      { "de": 1, "para": 2, "m": 1000 }, { "de": 1, "para": 3, "m": 1500 }, { "de": 2, "para": 4, "m": 1000 },
      { "de": 2, "para": 5, "m": 2500 }, { "de": 3, "para": 4, "m": 800 }, { "de": 3, "para": 5, "m": 3000 },
      { "de": 4, "para": 6, "m": 1000 }, { "de": 4, "para": 5, "m": 600 }, { "de": 5, "para": 6, "m": 500 }
    ],
    "origem": 1, "destino": 6, "kmh": 60,
    "atualizacoes": [{ "t": 90, "de": 2, "para": 4, "kmh": 5 }]
  },
  "via-libera": {
    "nos": [
      { "id": 1, "x": 0.08, "y": 0.5 }, { "id": 2, "x": 0.32, "y": 0.28 }, { "id": 3, "x": 0.32, "y": 0.74 },
      { "id": 4, "x": 0.62, "y": 0.28 }, { "id": 5, "x": 0.62, "y": 0.74 }, { "id": 6, "x": 0.92, "y": 0.5 }
    ],
    "arestas": [
      { "de": 1, "para": 2, "m": 1000 }, { "de": 1, "para": 3, "m": 1500 }, { "de": 2, "para": 4, "m": 1000 },
      { "de": 2, "para": 5, "m": 2500 }, { "de": 3, "para": 4, "m": 800 }, { "de": 3, "para": 5, "m": 3000 },
      { "de": 4, "para": 6, "m": 1000 }, { "de": 4, "para": 5, "m": 600 }, { "de": 5, "para": 6, "m": 500 }
    ],
    "origem": 1, "destino": 6, "kmh": 30,
    "atualizacoes": [{ "t": 60, "de": 2, "para": 5, "kmh": 120 }]
  }
}
```

Semântica esperada (o executor confere rodando o WASM da Task 1 Step 7 com `gerarEntrada` de cada um):
- `engarrafamento`: plano `1 2 4 6`; ao chegar em 2 (t=60) a via 2→4 já travou (t=30) → replaneja `2 5 6`. Total 240 s.
- `tarde-demais`: a mesma via trava em t=90, quando o carro **já está** em 2→4 (60→120). O C só aplica a atualização ao chegar em 4 (t=120): replaneja de 4 → `4 6`; total 180 s, igual ao plano original. A atualização não muda nada porque o modelo não interrompe uma via no meio — é o ponto do texto.
- `via-libera`: a 30 km/h tudo dobra: plano `1 2 4 6` (360 s). Em t=60 a via 2→5 vai para 120 km/h (2500 m → 75 s). O carro chega em 2 em t=120 ≥ 60 → replaneja: `2 5 6` = 75 + 60 = 135 s vs `2 4 6` = 240 s → desvia. Total 120+135 = 255 s.
- `dijkstra`: grade; sem atualização; o caminho mais rápido é pela linha do meio (800 m por quadra): `1 5 6 7 8 12` = 700+800×3+700 = 3800 m = 228 s — conferir contra alternativas (`1 2 3 4 8 12` = 4400 m). Anotar o caminho real na Task 9 (texto).

Se algum cenário não se comportar como descrito, ajustar distâncias/instantes **no JSON** até se comportar — a descrição acima é a intenção didática, o JSON é o meio.

- [ ] **Step 7: Teste Ruby** `test/routes_scenarios_test.rb`:

```ruby
require "test_helper"
require "json"

class RoutesScenariosTest < Minitest::Test
  include OutputHelpers

  def cenarios
    JSON.parse(output("demos/car-routes/cenarios.json").read)
  end

  def test_the_scenarios_are_published
    assert output("demos/car-routes/cenarios.json").file?
  end

  def test_the_four_scenarios_exist
    assert_equal %w[dijkstra engarrafamento tarde-demais via-libera], cenarios.keys.sort
  end

  def test_every_scenario_is_coherent
    cenarios.each do |id, c|
      ids = c["nos"].map { |n| n["id"] }
      assert_equal (1..ids.length).to_a, ids.sort, "#{id}: ids devem ser 1..N"
      c["nos"].each do |n|
        assert (0.0..1.0).cover?(n["x"]) && (0.0..1.0).cover?(n["y"]), "#{id}: no #{n['id']} fora de [0,1]"
      end
      c["arestas"].each do |a|
        assert ids.include?(a["de"]) && ids.include?(a["para"]), "#{id}: aresta #{a['de']}->#{a['para']} com no inexistente"
        assert_operator a["m"], :>, 0
      end
      refute_equal c["origem"], c["destino"], "#{id}: origem igual ao destino"
      assert_operator c["kmh"], :>, 0
      chaves = c["arestas"].map { |a| [a["de"], a["para"]] }
      c["atualizacoes"].each do |u|
        assert chaves.include?([u["de"], u["para"]]), "#{id}: atualizacao em via inexistente #{u['de']}->#{u['para']}"
        assert_operator u["kmh"], :>, 0
      end
      assert_equal c["atualizacoes"], c["atualizacoes"].sort_by { |u| u["t"] }, "#{id}: atualizacoes fora de ordem"
    end
  end

  def test_every_player_in_the_page_references_a_scenario
    %w[projects/car-routes/index.html pt/projects/car-routes/index.html].each do |pagina|
      usados = page_body(pagina).scan(/data-rotas="([^"]+)"/).flatten.uniq
      refute_empty usados
      (usados - cenarios.keys).each { |id| flunk "#{pagina} usa o cenario #{id}, que nao existe" }
    end
  end
end
```

- [ ] **Step 8: `rake check`** → verde (Ruby + `npm test`).

- [ ] **Step 9: Commit**

```bash
git add package.json Rakefile src/demos/car-routes/cenarios.json frontend/javascript/routes-entrada.js test/js test/routes_scenarios_test.rb
git commit -m "Adiciona os cenarios de rotas e a geracao da entrada do C"
```

---

### Task 4: Parse do trace e redução de estado

**Files:**
- Create: `frontend/javascript/routes-trace.js`, `test/js/routes-trace.test.mjs`

**Interfaces:**
- Produces:
  - `analisar(texto) → Evento[]`, onde `Evento` é um de: `{tipo:"graph", n, e}`, `{tipo:"edge", de, para, m, kmh}`, `{tipo:"replan", no, t}`, `{tipo:"pop", no, t}`, `{tipo:"relax", de, para, t}`, `{tipo:"plan", caminho:number[], eta:number|null}`, `{tipo:"move", de, para, t0, t1}`, `{tipo:"update", de, para, kmh, t}`, `{tipo:"unreachable", no, t}`, `{tipo:"done", t, km}`.
  - `estadoInicial(eventos) → Estado`; `reduzir(estado, evento) → Estado` (novo objeto; `arestas` é um `Map` copiado).
  - `Estado = { arestas: Map<"de-para", {de, para, m, kmh}>, relogio, base, fechados: Set<number>, abertos: Map<number, number>, relaxada: {de,para}|null, planejado: number[], percorrido: number[], carro: {de,para,t0,t1}|null, atualizada: {de,para,t}|null, fim: {t,km}|null, inalcancavel: boolean }`.
  - `duracaoMs(evento, escala) → number` (ms reais em 1×; `escala` multiplica).

- [ ] **Step 1: Teste** `test/js/routes-trace.test.mjs`:

```js
import { test } from "node:test"
import assert from "node:assert/strict"
import { analisar, estadoInicial, reduzir, duracaoMs } from "../../frontend/javascript/routes-trace.js"

const TRACE = `graph 3 2
edge 1 2 1000 60.000
edge 2 3 500 60.000
replan 1 0.000
pop 1 0.000
relax 1 2 60.000
pop 2 60.000
relax 2 3 90.000
pop 3 90.000
plan 1 2 3 90.000
move 1 2 0.000 60.000
update 2 3 5.000 60.000
replan 2 60.000
pop 2 0.000
relax 2 3 360.000
pop 3 360.000
plan 2 3 360.000
move 2 3 60.000 420.000
done 420.000 1.500
`

test("analisar converte cada linha num evento tipado", () => {
  const ev = analisar(TRACE)
  assert.equal(ev.length, 19)
  assert.deepEqual(ev[0], { tipo: "graph", n: 3, e: 2 })
  assert.deepEqual(ev[1], { tipo: "edge", de: 1, para: 2, m: 1000, kmh: 60 })
  assert.deepEqual(ev[9], { tipo: "plan", caminho: [1, 2, 3], eta: 90 })
  assert.deepEqual(ev[10], { tipo: "move", de: 1, para: 2, t0: 0, t1: 60 })
  assert.deepEqual(ev[11], { tipo: "update", de: 2, para: 3, kmh: 5, t: 60 })
  assert.deepEqual(ev[18], { tipo: "done", t: 420, km: 1.5 })
})

test("plan com destino inalcancavel tem eta null", () => {
  assert.deepEqual(analisar("plan 3 unreachable\n")[0], { tipo: "plan", caminho: [3], eta: null })
})

test("estadoInicial carrega as arestas e mais nada", () => {
  const s = estadoInicial(analisar(TRACE))
  assert.equal(s.arestas.size, 2)
  assert.deepEqual(s.arestas.get("2-3"), { de: 2, para: 3, m: 500, kmh: 60 })
  assert.equal(s.relogio, 0)
  assert.deepEqual([...s.fechados], [])
  assert.equal(s.carro, null)
})

test("reduzir acompanha o Dijkstra e o carro", () => {
  const ev = analisar(TRACE)
  let s = estadoInicial(ev)
  for (const e of ev.slice(0, 10)) s = reduzir(s, e)
  assert.deepEqual([...s.fechados].sort(), [1, 2, 3])
  assert.deepEqual(s.planejado, [1, 2, 3])
  s = reduzir(s, ev[10])
  assert.deepEqual(s.percorrido, [1, 2])
  assert.deepEqual(s.carro, { de: 1, para: 2, t0: 0, t1: 60 })
  assert.equal(s.relogio, 60)
  s = reduzir(s, ev[11])
  assert.equal(s.arestas.get("2-3").kmh, 5)
  assert.deepEqual(s.atualizada, { de: 2, para: 3, t: 60 })
  s = reduzir(s, ev[12])
  assert.deepEqual([...s.fechados], [])
  assert.equal(s.base, 60)
  assert.deepEqual(s.planejado, [])
})

test("abertos guarda o tempo do relax e sai no pop", () => {
  const ev = analisar(TRACE)
  let s = estadoInicial(ev)
  for (const e of ev.slice(0, 6)) s = reduzir(s, e)
  assert.deepEqual([...s.abertos], [[2, 60]])
  s = reduzir(s, ev[6])
  assert.deepEqual([...s.abertos], [])
  s = reduzir(s, ev[7])
  assert.deepEqual([...s.abertos], [[3, 90]])
})

test("done fecha o estado", () => {
  const ev = analisar(TRACE)
  const s = ev.reduce(reduzir, estadoInicial(ev))
  assert.deepEqual(s.fim, { t: 420, km: 1.5 })
  assert.deepEqual(s.percorrido, [1, 2, 3])
})

test("reduzir nao muta o estado anterior", () => {
  const ev = analisar(TRACE)
  const a = estadoInicial(ev)
  reduzir(a, ev[11])
  assert.equal(a.arestas.get("2-3").kmh, 60)
})

test("duracaoMs", () => {
  assert.equal(duracaoMs({ tipo: "pop" }, 1), 250)
  assert.equal(duracaoMs({ tipo: "move", t0: 0, t1: 60 }, 1), 1000)
  assert.equal(duracaoMs({ tipo: "move", t0: 0, t1: 60 }, 4), 250)
  assert.equal(duracaoMs({ tipo: "done" }, 1), 0)
})
```

- [ ] **Step 2: Rodar** `npm test` → falhas do módulo ausente.

- [ ] **Step 3: Módulo** `frontend/javascript/routes-trace.js`:

```js
import { chaveAresta } from "./routes-entrada.js"

const SEGUNDOS_SIMULADOS_POR_SEGUNDO = 60
const PASSO_MS = { pop: 250, relax: 250, replan: 400, plan: 600, update: 600, unreachable: 600, graph: 0, edge: 0, done: 0 }

export function analisar(texto) {
  return texto
    .split("\n")
    .filter((l) => l.trim() !== "")
    .map((linha) => {
      const [tipo, ...c] = linha.trim().split(/\s+/)
      const n = c.map(Number)
      switch (tipo) {
        case "graph": return { tipo, n: n[0], e: n[1] }
        case "edge": return { tipo, de: n[0], para: n[1], m: n[2], kmh: n[3] }
        case "replan": return { tipo, no: n[0], t: n[1] }
        case "pop": return { tipo, no: n[0], t: n[1] }
        case "relax": return { tipo, de: n[0], para: n[1], t: n[2] }
        case "plan": {
          const ultimo = c[c.length - 1]
          const eta = ultimo === "unreachable" ? null : Number(ultimo)
          return { tipo, caminho: n.slice(0, -1), eta }
        }
        case "move": return { tipo, de: n[0], para: n[1], t0: n[2], t1: n[3] }
        case "update": return { tipo, de: n[0], para: n[1], kmh: n[2], t: n[3] }
        case "unreachable": return { tipo, no: n[0], t: n[1] }
        case "done": return { tipo, t: n[0], km: n[1] }
        default: return { tipo: "ignorado", linha }
      }
    })
    .filter((e) => e.tipo !== "ignorado")
}

export function estadoInicial(eventos) {
  const arestas = new Map()
  for (const e of eventos) {
    if (e.tipo === "edge") arestas.set(chaveAresta(e.de, e.para), { de: e.de, para: e.para, m: e.m, kmh: e.kmh })
  }
  return {
    arestas, relogio: 0, base: 0,
    fechados: new Set(), abertos: new Map(), relaxada: null,
    planejado: [], percorrido: [], carro: null, atualizada: null, fim: null, inalcancavel: false,
  }
}

export function reduzir(estado, e) {
  const s = {
    ...estado,
    arestas: new Map([...estado.arestas].map(([k, v]) => [k, { ...v }])),
    fechados: new Set(estado.fechados),
    abertos: new Map(estado.abertos),
    planejado: [...estado.planejado],
    percorrido: [...estado.percorrido],
    relaxada: null,
  }
  switch (e.tipo) {
    case "replan":
      s.base = e.t; s.fechados.clear(); s.abertos.clear(); s.planejado = []; s.carro = null; s.atualizada = null
      break
    case "pop":
      s.abertos.delete(e.no); s.fechados.add(e.no)
      break
    case "relax":
      s.abertos.set(e.para, e.t); s.relaxada = { de: e.de, para: e.para }
      break
    case "plan":
      s.planejado = e.caminho
      break
    case "move":
      if (s.percorrido.length === 0) s.percorrido.push(e.de)
      s.percorrido.push(e.para)
      s.carro = { de: e.de, para: e.para, t0: e.t0, t1: e.t1 }
      s.relogio = e.t1
      break
    case "update": {
      const a = s.arestas.get(chaveAresta(e.de, e.para))
      if (a) a.kmh = e.kmh
      s.atualizada = { de: e.de, para: e.para, t: e.t }
      s.relogio = e.t
      break
    }
    case "unreachable":
      s.inalcancavel = true
      break
    case "done":
      s.fim = { t: e.t, km: e.km }
      break
  }
  return s
}

export function duracaoMs(e, escala) {
  const base = e.tipo === "move" ? ((e.t1 - e.t0) / SEGUNDOS_SIMULADOS_POR_SEGUNDO) * 1000 : PASSO_MS[e.tipo] ?? 0
  return base / escala
}
```

- [ ] **Step 4: Rodar** `npm test` → todos passam. Provar por remoção: comentar `s.relogio = e.t1` no `move`, ver o teste "reduzir acompanha..." falhar, desfazer.

- [ ] **Step 5: Commit**

```bash
git add frontend/javascript/routes-trace.js test/js/routes-trace.test.mjs
git commit -m "Analisa o trace do simulador e reconstroi o estado por evento"
```

---

### Task 5: Carregador do WASM

**Files:**
- Create: `frontend/javascript/routes-wasm.js`, `test/js/routes-wasm.test.mjs`

**Interfaces:**
- Consumes: `criarRotas` (Task 1).
- Produces: `criarSimulador({ carregarScript }) → { rodar(entrada) → Promise<string> }` — `carregarScript(url) → Promise<Function>` é injetado: no navegador injeta `<script>` e resolve `window.criarRotas`; no teste, `require`. O módulo Emscripten é instanciado **uma vez** na primeira chamada; as seguintes só chamam `run_trace`.

- [ ] **Step 1: Teste** `test/js/routes-wasm.test.mjs` (usa os artefatos reais):

```js
import { test } from "node:test"
import assert from "node:assert/strict"
import { createRequire } from "node:module"
import { readFileSync } from "node:fs"
import { criarSimulador } from "../../frontend/javascript/routes-wasm.js"
import { gerarEntrada } from "../../frontend/javascript/routes-entrada.js"

const require = createRequire(import.meta.url)
const carregarScript = async () => require("../../src/demos/car-routes/rotas.js")
const cenarios = JSON.parse(readFileSync(new URL("../../src/demos/car-routes/cenarios.json", import.meta.url)))

test("roda o cenario engarrafamento e termina em done", async () => {
  const sim = criarSimulador({ carregarScript })
  const trace = await sim.rodar(gerarEntrada(cenarios.engarrafamento))
  const linhas = trace.trim().split("\n")
  assert.equal(linhas[0], "graph 6 9")
  assert.equal(linhas.at(-1), "done 240.000 4.000")
  assert.ok(linhas.includes("plan 2 5 6 180.000"))
})

test("duas rodadas seguidas nao misturam a saida", async () => {
  const sim = criarSimulador({ carregarScript })
  const a = await sim.rodar(gerarEntrada(cenarios.engarrafamento))
  const b = await sim.rodar(gerarEntrada(cenarios["tarde-demais"]))
  assert.equal(a.match(/^done/gm).length, 1)
  assert.equal(b.match(/^done/gm).length, 1)
  assert.notEqual(a, b)
})

test("entrada invalida rejeita", async () => {
  const sim = criarSimulador({ carregarScript })
  await assert.rejects(sim.rodar("0;0\n1;1\n0\n"))
})
```

- [ ] **Step 2: Rodar** `npm test` → falha.

- [ ] **Step 3: Módulo** `frontend/javascript/routes-wasm.js`:

```js
export function criarSimulador({ carregarScript }) {
  let modulo = null
  let saida = []

  async function instanciar(base) {
    const criarRotas = await carregarScript(`${base}/rotas.js`)
    return criarRotas({
      print: (linha) => saida.push(linha),
      printErr: (linha) => console.warn("[rotas]", linha),
      locateFile: (arquivo) => `${base}/${arquivo}`,
    })
  }

  return {
    async rodar(entrada, base = "/demos/car-routes") {
      if (!modulo) modulo = await instanciar(base)
      saida = []
      const codigo = modulo.ccall("run_trace", "number", ["string"], [entrada])
      if (codigo !== 0) throw new Error(`run_trace retornou ${codigo}`)
      return saida.join("\n") + "\n"
    },
  }
}

export function carregarScriptNoNavegador(url) {
  return new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = url
    script.onerror = () => reject(new Error(`nao foi possivel carregar ${url}`))
    script.onload = () => resolve(window.criarRotas)
    document.head.appendChild(script)
  })
}
```

- [ ] **Step 4: Rodar** `npm test` → passa. Se "entrada invalida rejeita" falhar porque `run_trace` retorna 0 para `0;0`, a validação do plano 1 (Task 4, `node_amount <= 0` → retorno 2) não está no artefato: reconstruir com `rake routes:build` no SHA certo.

- [ ] **Step 5: Commit**

```bash
git add frontend/javascript/routes-wasm.js test/js/routes-wasm.test.mjs
git commit -m "Carrega o simulador WebAssembly uma vez e roda traces sob demanda"
```

---

### Task 6: Desenho no canvas

**Files:**
- Create: `frontend/javascript/routes-desenho.js`, `test/js/routes-desenho.test.mjs`

**Interfaces:**
- Consumes: `Estado` (Task 4), cenário (Task 3).
- Produces: `desenhar(ctx, cenario, estado, progresso, tema, largura, altura)` — `progresso` ∈ [0,1] é o quanto do evento corrente já passou (usado só pelo carro em `move`); `tema = { bg, fg, muted, accent, border, bgSutil }` strings CSS. `posicao(cenario, id, largura, altura) → {x, y}` em px. `arestaMaisProxima(cenario, x, y, largura, altura) → {de, para}|null` (para o editor; distância ≤ 12 px).

- [ ] **Step 1: Teste** `test/js/routes-desenho.test.mjs` com um `ctx` gravador:

```js
import { test } from "node:test"
import assert from "node:assert/strict"
import { desenhar, posicao, arestaMaisProxima } from "../../frontend/javascript/routes-desenho.js"
import { analisar, estadoInicial, reduzir } from "../../frontend/javascript/routes-trace.js"

const cenario = {
  nos: [{ id: 1, x: 0, y: 0.5 }, { id: 2, x: 0.5, y: 0.5 }, { id: 3, x: 1, y: 0.5 }],
  arestas: [{ de: 1, para: 2, m: 1000 }, { de: 2, para: 3, m: 500 }],
  origem: 1, destino: 3, kmh: 60, atualizacoes: [],
}
const tema = { bg: "#fff", fg: "#000", muted: "#888", accent: "#c00", border: "#ccc", bgSutil: "#eee" }

function gravador() {
  const chamadas = []
  const ctx = new Proxy({}, {
    get: (_, nome) => (nome === "chamadas" ? chamadas : (...args) => { chamadas.push([nome, ...args]); return ctx }),
    set: (_, nome, valor) => { chamadas.push(["set", nome, valor]); return true },
  })
  return ctx
}

test("posicao respeita a margem", () => {
  assert.deepEqual(posicao(cenario, 1, 300, 200), { x: 24, y: 100 })
  assert.deepEqual(posicao(cenario, 3, 300, 200), { x: 276, y: 100 })
})

test("desenha um arco por no e uma linha por aresta", () => {
  const ctx = gravador()
  const ev = analisar("graph 3 2\nedge 1 2 1000 60.000\nedge 2 3 500 60.000\n")
  desenhar(ctx, cenario, estadoInicial(ev), 0, tema, 300, 200)
  assert.equal(ctx.chamadas.filter((c) => c[0] === "arc").length, 3)
  assert.equal(ctx.chamadas.filter((c) => c[0] === "lineTo").length >= 2, true)
})

test("o carro fica no meio da via com progresso 0.5", () => {
  const ctx = gravador()
  const ev = analisar("graph 3 2\nedge 1 2 1000 60.000\nedge 2 3 500 60.000\nmove 1 2 0.000 60.000\n")
  const estado = ev.reduce(reduzir, estadoInicial(ev))
  desenhar(ctx, cenario, estado, 0.5, tema, 300, 200)
  const arcos = ctx.chamadas.filter((c) => c[0] === "arc")
  const carro = arcos.at(-1)
  assert.equal(carro[1], 87)
  assert.equal(carro[2], 100)
})

test("arestaMaisProxima acha a via sob o ponto e ignora o longe", () => {
  assert.deepEqual(arestaMaisProxima(cenario, 87, 104, 300, 200), { de: 1, para: 2 })
  assert.equal(arestaMaisProxima(cenario, 87, 160, 300, 200), null)
})
```

- [ ] **Step 2: Rodar** `npm test` → falha.

- [ ] **Step 3: Módulo** `frontend/javascript/routes-desenho.js`:

```js
import { chaveAresta } from "./routes-entrada.js"

const MARGEM = 24
const RAIO_NO = 9
const RAIO_CARRO = 6
const TOLERANCIA_CLIQUE = 12

export function posicao(cenario, id, largura, altura) {
  const no = cenario.nos.find((n) => n.id === id)
  return { x: MARGEM + no.x * (largura - 2 * MARGEM), y: MARGEM + no.y * (altura - 2 * MARGEM) }
}

function espessura(kmh) {
  return Math.max(1, Math.min(6, kmh / 15))
}

function seta(ctx, a, b, cor) {
  const ang = Math.atan2(b.y - a.y, b.x - a.x)
  const px = b.x - Math.cos(ang) * (RAIO_NO + 2)
  const py = b.y - Math.sin(ang) * (RAIO_NO + 2)
  ctx.fillStyle = cor
  ctx.beginPath()
  ctx.moveTo(px, py)
  ctx.lineTo(px - Math.cos(ang - 0.5) * 8, py - Math.sin(ang - 0.5) * 8)
  ctx.lineTo(px - Math.cos(ang + 0.5) * 8, py - Math.sin(ang + 0.5) * 8)
  ctx.closePath()
  ctx.fill()
}

function linha(ctx, a, b, cor, grossura, tracejada) {
  ctx.strokeStyle = cor
  ctx.lineWidth = grossura
  ctx.setLineDash(tracejada ? [6, 6] : [])
  ctx.beginPath()
  ctx.moveTo(a.x, a.y)
  ctx.lineTo(b.x, b.y)
  ctx.stroke()
  ctx.setLineDash([])
}

function pares(caminho) {
  return caminho.slice(1).map((para, i) => [caminho[i], para])
}

export function desenhar(ctx, cenario, estado, progresso, tema, largura, altura) {
  const p = (id) => posicao(cenario, id, largura, altura)
  ctx.clearRect(0, 0, largura, altura)

  for (const a of estado.arestas.values()) {
    const atualizada = estado.atualizada && estado.atualizada.de === a.de && estado.atualizada.para === a.para
    const relaxada = estado.relaxada && estado.relaxada.de === a.de && estado.relaxada.para === a.para
    const cor = atualizada || relaxada ? tema.accent : tema.border
    linha(ctx, p(a.de), p(a.para), cor, espessura(a.kmh), false)
    seta(ctx, p(a.de), p(a.para), cor)
  }

  for (const [de, para] of pares(estado.planejado)) linha(ctx, p(de), p(para), tema.accent, 2, true)
  for (const [de, para] of pares(estado.percorrido)) linha(ctx, p(de), p(para), tema.fg, 3, false)

  ctx.font = "12px ui-monospace, monospace"
  ctx.textAlign = "center"
  ctx.textBaseline = "middle"
  for (const no of cenario.nos) {
    const { x, y } = p(no.id)
    const fechado = estado.fechados.has(no.id)
    const aberto = estado.abertos.has(no.id)
    ctx.beginPath()
    ctx.arc(x, y, RAIO_NO, 0, Math.PI * 2)
    ctx.fillStyle = fechado ? tema.muted : tema.bg
    ctx.fill()
    ctx.lineWidth = aberto ? 3 : 1.5
    ctx.strokeStyle = aberto ? tema.accent : tema.fg
    ctx.stroke()
    ctx.fillStyle = fechado ? tema.bg : tema.fg
    ctx.fillText(String(no.id), x, y)
    if (no.id === cenario.origem || no.id === cenario.destino) {
      ctx.fillStyle = tema.muted
      ctx.fillText(no.id === cenario.origem ? "A" : "B", x, y - RAIO_NO - 9)
    }
  }

  if (estado.carro) {
    const a = p(estado.carro.de)
    const b = p(estado.carro.para)
    const x = a.x + (b.x - a.x) * progresso
    const y = a.y + (b.y - a.y) * progresso
    ctx.beginPath()
    ctx.arc(x, y, RAIO_CARRO, 0, Math.PI * 2)
    ctx.fillStyle = tema.accent
    ctx.fill()
  }
}

export function arestaMaisProxima(cenario, x, y, largura, altura) {
  let melhor = null
  let menor = TOLERANCIA_CLIQUE
  for (const a of cenario.arestas) {
    const p1 = posicao(cenario, a.de, largura, altura)
    const p2 = posicao(cenario, a.para, largura, altura)
    const dx = p2.x - p1.x, dy = p2.y - p1.y
    const t = Math.max(0, Math.min(1, ((x - p1.x) * dx + (y - p1.y) * dy) / (dx * dx + dy * dy)))
    const d = Math.hypot(x - (p1.x + t * dx), y - (p1.y + t * dy))
    if (d < menor) { menor = d; melhor = { de: a.de, para: a.para } }
  }
  return melhor
}
```
Conferir a conta do teste "o carro fica no meio": nó 1 em x=24, nó 2 em x=24+0.5×252=150; meio = 87. ✔.

- [ ] **Step 4: Rodar** `npm test` → passa.

- [ ] **Step 5: Commit**

```bash
git add frontend/javascript/routes-desenho.js test/js/routes-desenho.test.mjs
git commit -m "Desenha o grafo, a fronteira do Dijkstra e o carro no canvas"
```

---

### Task 7: Player — montagem, relógio, controles, painel

**Files:**
- Create: `frontend/javascript/routes-player.js`, `test/routes_player_test.rb`
- Modify: `frontend/javascript/index.js` (`import "./routes-player.js"`)

**Interfaces:**
- Consumes: Tasks 3–6.
- Produces: para cada `[data-rotas]` na página, um player. Atributos que o player escreve no elemento raiz, para o Playwright e para testes: `data-rotas-estado` (`"pronto" | "rodando" | "pausado" | "fim" | "erro"`), `data-rotas-caminho` (ex.: `"1 2 5 6"` ao fim), `data-rotas-relogio` (segundos inteiros). Método público via `raiz.__rotas = { rodar(), pausar(), passo(), reiniciar(), definirCenario(cenario) }` — o editor (Task 8) usa `definirCenario`.

- [ ] **Step 1: Teste Ruby** `test/routes_player_test.rb` (o bundle é o que a página serve):

```ruby
require "test_helper"

class RoutesPlayerTest < Minitest::Test
  include OutputHelpers

  def bundle
    corpo = page_body("projects/car-routes/index.html")
    src = corpo[/<script[^>]+src="([^"]+\.js)"/, 1]
    refute_nil src, "a pagina nao carrega o bundle"
    output(src.sub(%r{\A/}, "")).read
  end

  def test_the_bundle_mounts_the_routes_players
    %w[data-rotas data-rotas-canvas data-rotas-controles data-rotas-painel data-rotas-erro
       data-rotas-textos data-rotas-base data-rotas-estado data-rotas-caminho run_trace].each do |gancho|
      assert_includes bundle, gancho, "o bundle nao referencia #{gancho}"
    end
  end
end
```

- [ ] **Step 2: Rodar** → falha (bundle sem os ganchos).

- [ ] **Step 3: Módulo** `frontend/javascript/routes-player.js`:

```js
import { gerarEntrada, chaveAresta } from "./routes-entrada.js"
import { analisar, estadoInicial, reduzir, duracaoMs } from "./routes-trace.js"
import { criarSimulador, carregarScriptNoNavegador } from "./routes-wasm.js"
import { desenhar } from "./routes-desenho.js"

const simulador = criarSimulador({ carregarScript: carregarScriptNoNavegador })
let cenariosPromessa = null

function carregarCenarios(base) {
  if (!cenariosPromessa) cenariosPromessa = fetch(`${base}/cenarios.json`).then((r) => r.json())
  return cenariosPromessa
}

function tema() {
  const estilo = getComputedStyle(document.documentElement)
  const cor = (nome) => estilo.getPropertyValue(nome).trim()
  return { bg: cor("--bg"), bgSutil: cor("--bg-sutil"), fg: cor("--fg"), muted: cor("--muted"), accent: cor("--accent"), border: cor("--border") }
}

function textosDe(raiz) {
  const proprio = raiz.getAttribute("data-rotas-textos")
  const fonte = proprio ? raiz : document.querySelector("[data-rotas-textos]")
  return fonte ? JSON.parse(fonte.getAttribute("data-rotas-textos")) : {}
}

function botao(texto, aoClicar) {
  const b = document.createElement("button")
  b.type = "button"
  b.textContent = texto
  b.addEventListener("click", aoClicar)
  return b
}

function relogioTexto(segundos) {
  const s = Math.max(0, Math.round(segundos))
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`
}

export function montar(raiz) {
  const id = raiz.getAttribute("data-rotas")
  const base = raiz.getAttribute("data-rotas-base") || document.querySelector("[data-rotas-base]")?.getAttribute("data-rotas-base") || "/demos/car-routes"
  const garantir = (gancho, tag, classe) => {
    let el = raiz.querySelector(`[${gancho}]`)
    if (!el) {
      el = document.createElement(tag)
      el.setAttribute(gancho, "")
      if (classe) el.className = classe
      raiz.append(el)
    }
    return el
  }
  const canvas = garantir("data-rotas-canvas", "canvas")
  const controles = garantir("data-rotas-controles", "div", "rotas-controles")
  const painel = garantir("data-rotas-painel", "aside", "rotas-painel")
  const erro = raiz.querySelector("[data-rotas-erro]")
  const t = textosDe(raiz)
  const ctx = canvas.getContext("2d")

  let cenario = null
  let eventos = []
  let estados = []
  let indice = 0
  let decorrido = 0
  let escala = 1
  let rodando = false
  let ultimoQuadro = 0

  const btRodar = botao(t.play, () => (rodando ? pausar() : rodar()))
  const btPasso = botao(t.step, () => { pausar(); avancar() })
  const btVelocidade = botao(`${t.speed} 1×`, () => { escala = escala === 1 ? 4 : 1; btVelocidade.textContent = `${t.speed} ${escala}×` })
  const btReiniciar = botao(t.restart, () => reiniciar())
  controles.replaceChildren(btRodar, btPasso, btVelocidade, btReiniciar)

  const dl = document.createElement("dl")
  const ddRelogio = document.createElement("dd")
  const ddFila = document.createElement("dd")
  ddFila.className = "rotas-fila"
  const ddKm = document.createElement("dd")
  for (const [rotulo, dd] of [[t.clock, ddRelogio], [t.queue, ddFila], [t.km, ddKm]]) {
    const dt = document.createElement("dt")
    dt.textContent = rotulo
    dl.append(dt, dd)
  }
  const legenda = document.createElement("p")
  legenda.className = "rotas-legenda"
  for (const [classe, texto] of [["aberto", t.legend_open], ["fechado", t.legend_closed], ["planejado", t.legend_planned], ["percorrido", t.legend_driven]]) {
    const span = document.createElement("span")
    span.className = classe
    span.textContent = texto
    legenda.append(span)
  }
  painel.replaceChildren(dl, legenda)

  function tamanho() {
    const dpr = window.devicePixelRatio || 1
    const largura = canvas.clientWidth
    const altura = Math.round(largura * 2 / 3)
    if (canvas.width !== largura * dpr || canvas.height !== altura * dpr) {
      canvas.width = largura * dpr
      canvas.height = altura * dpr
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    return { largura, altura }
  }

  function estadoAtual() {
    return estados[Math.min(indice, estados.length - 1)]
  }

  function quadro() {
    if (!cenario) return
    const { largura, altura } = tamanho()
    const e = eventos[indice]
    const dur = e ? duracaoMs(e, escala) : 0
    const progresso = e && e.tipo === "move" && dur > 0 ? Math.min(1, decorrido / dur) : 1
    desenhar(ctx, cenario, estadoAtual(), progresso, tema(), largura, altura)
    const s = estadoAtual()
    const relogio = e && e.tipo === "move" ? e.t0 + (e.t1 - e.t0) * progresso : s.relogio
    ddRelogio.textContent = relogioTexto(relogio)
    raiz.setAttribute("data-rotas-relogio", String(Math.round(relogio)))
    ddFila.replaceChildren(...[...s.abertos].sort((a, b) => a[1] - b[1]).map(([no, tempo]) => {
      const span = document.createElement("span")
      span.textContent = `${no}: ${relogioTexto(tempo)}`
      return span
    }))
    ddKm.textContent = s.fim ? `${s.fim.km.toFixed(1)} ${t.km} · ${relogioTexto(s.fim.t)}` : ""
  }

  function avancar() {
    if (indice >= eventos.length) return
    indice++
    decorrido = 0
    if (indice >= eventos.length) terminar()
    quadro()
  }

  function terminar() {
    rodando = false
    btRodar.textContent = t.play
    btRodar.setAttribute("aria-pressed", "false")
    const s = estadoAtual()
    raiz.setAttribute("data-rotas-estado", s.inalcancavel ? "erro" : "fim")
    raiz.setAttribute("data-rotas-caminho", s.percorrido.join(" "))
    if (s.inalcancavel && erro) { erro.hidden = false; erro.textContent = t.unreachable }
  }

  function laco(agora) {
    if (!rodando) return
    decorrido += agora - ultimoQuadro
    ultimoQuadro = agora
    const e = eventos[indice]
    if (e && decorrido >= duracaoMs(e, escala)) {
      avancar()
      if (!rodando) return
    }
    quadro()
    requestAnimationFrame(laco)
  }

  async function rodar() {
    if (eventos.length === 0) {
      btRodar.disabled = true
      try {
        await carregarTrace()
      } catch (motivo) {
        console.error("[rotas]", motivo)
        raiz.setAttribute("data-rotas-estado", "erro")
        if (erro) erro.hidden = false
        return
      } finally {
        btRodar.disabled = false
      }
    }
    if (indice >= eventos.length) reiniciar()
    rodando = true
    btRodar.textContent = t.pause
    btRodar.setAttribute("aria-pressed", "true")
    raiz.setAttribute("data-rotas-estado", "rodando")
    ultimoQuadro = performance.now()
    requestAnimationFrame(laco)
  }

  function pausar() {
    rodando = false
    btRodar.textContent = t.play
    btRodar.setAttribute("aria-pressed", "false")
    if (eventos.length) raiz.setAttribute("data-rotas-estado", "pausado")
  }

  function reiniciar() {
    pausar()
    indice = 0
    decorrido = 0
    raiz.removeAttribute("data-rotas-caminho")
    raiz.setAttribute("data-rotas-estado", eventos.length ? "pausado" : "pronto")
    quadro()
  }

  async function carregarTrace() {
    const trace = await simulador.rodar(gerarEntrada(cenario), base)
    eventos = analisar(trace)
    estados = [estadoInicial(eventos)]
    for (const e of eventos) estados.push(reduzir(estados.at(-1), e))
    indice = 0
    decorrido = 0
  }

  function definirCenario(novo) {
    cenario = novo
    eventos = []
    estados = [estadoInicial([])]
    for (const a of novo.arestas) estados[0].arestas.set(chaveAresta(a.de, a.para), { de: a.de, para: a.para, m: a.m, kmh: novo.kmh })
    reiniciar()
  }

  raiz.__rotas = { rodar, pausar, passo: () => { pausar(); avancar() }, reiniciar, definirCenario, cenarioAtual: () => cenario }
  raiz.setAttribute("data-rotas-estado", "pronto")
  window.addEventListener("resize", quadro)

  carregarCenarios(base)
    .then((cenarios) => {
      if (!cenarios[id]) throw new Error(`cenario ${id} nao existe`)
      definirCenario(structuredClone(cenarios[id]))
    })
    .catch((motivo) => {
      console.error("[rotas]", motivo)
      raiz.setAttribute("data-rotas-estado", "erro")
      if (erro) erro.hidden = false
    })
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-rotas]").forEach(montar)
})
```
E em `index.js`, após `import "./wasm-player.js"`: `import "./routes-player.js"`.

- [ ] **Step 4: Testar no navegador de verdade** — `bin/bridgetown start` (Node 22), abrir `http://localhost:4000/pt/projects/car-routes/`: o grafo do cenário `engarrafamento` aparece antes de qualquer clique; "Rodar" carrega o WASM, anima os `pop`/`relax`, o carro anda, a via 2→4 pisca em acento no `update`, o replanejamento desvia por 5, e o painel mostra `4.0 km · 04:00`. Trocar o tema: as cores acompanham. Corrigir o que não bater.

- [ ] **Step 5: `rake check`** → verde.

- [ ] **Step 6: Commit**

```bash
git add frontend/javascript/routes-player.js frontend/javascript/index.js test/routes_player_test.rb
git commit -m "Player do simulador de rotas: relogio, controles e painel"
```

---

### Task 8: Editor de trânsito

**Files:**
- Modify: `frontend/javascript/routes-player.js` (função `montarEditor`, chamada em `montar` quando `raiz.hasAttribute("data-rotas-editor")`)
- Modify: `test/routes_player_test.rb` (ganchos do editor no bundle)

**Interfaces:**
- Consumes: `raiz.__rotas.definirCenario`, `arestaMaisProxima` (Task 6), `chaveAresta`.
- Produces: `data-rotas-editor-form`, `data-rotas-editor-lista`, `data-rotas-editor-rodar`, `data-rotas-editor-restaurar`, `data-rotas-editor-erro` no DOM.

- [ ] **Step 1: Teste** — acrescentar ao array de ganchos do `routes_player_test.rb`: `data-rotas-editor data-rotas-editor-form data-rotas-editor-lista data-rotas-editor-rodar data-rotas-editor-restaurar`. Rodar → falha.

- [ ] **Step 2: Implementar** em `routes-player.js`:

```js
import { arestaMaisProxima } from "./routes-desenho.js"

function montarEditor(raiz, canvas, t) {
  const original = structuredClone(raiz.__rotas.cenarioAtual())
  let cenario = structuredClone(original)
  let selecionada = null

  const caixa = document.createElement("div")
  caixa.className = "rotas-editor"
  const dica = document.createElement("p")
  dica.textContent = t.editor_hint
  const form = document.createElement("form")
  form.setAttribute("data-rotas-editor-form", "")
  form.hidden = true
  const rotulo = document.createElement("strong")
  const campo = (nome, texto, valor) => {
    const label = document.createElement("label")
    label.textContent = texto
    const input = document.createElement("input")
    input.name = nome
    input.type = "number"
    input.min = "0"
    input.step = "1"
    input.value = valor
    input.required = true
    label.append(input)
    return label
  }
  const instante = campo("instante", t.instant, "0")
  const kmh = campo("kmh", t.kmh, "5")
  const btAplicar = botao(t.apply, () => {})
  btAplicar.type = "submit"
  form.append(rotulo, instante, kmh, btAplicar)
  const lista = document.createElement("ul")
  lista.setAttribute("data-rotas-editor-lista", "")
  const btRodar = botao(t.run, () => aplicar())
  btRodar.setAttribute("data-rotas-editor-rodar", "")
  const btRestaurar = botao(t.reset, () => { cenario = structuredClone(original); renderLista(); aplicar() })
  btRestaurar.setAttribute("data-rotas-editor-restaurar", "")
  const erroEditor = document.createElement("p")
  erroEditor.className = "rotas-erro"
  erroEditor.setAttribute("data-rotas-editor-erro", "")
  caixa.append(dica, form, lista, btRodar, btRestaurar, erroEditor)
  raiz.append(caixa)

  canvas.addEventListener("click", (evento) => {
    const r = canvas.getBoundingClientRect()
    const aresta = arestaMaisProxima(cenario, evento.clientX - r.left, evento.clientY - r.top, r.width, r.height)
    if (!aresta) return
    selecionada = aresta
    rotulo.textContent = `${aresta.de} → ${aresta.para}`
    form.hidden = false
    instante.querySelector("input").focus()
  })

  form.addEventListener("submit", (evento) => {
    evento.preventDefault()
    const tI = Number(instante.querySelector("input").value)
    const v = Number(kmh.querySelector("input").value)
    if (!selecionada || !(tI >= 0) || !(v > 0)) { erroEditor.textContent = `${t.instant} ≥ 0, ${t.kmh} > 0`; return }
    erroEditor.textContent = ""
    cenario.atualizacoes = cenario.atualizacoes.filter((u) => !(u.de === selecionada.de && u.para === selecionada.para && u.t === tI))
    cenario.atualizacoes.push({ t: tI, de: selecionada.de, para: selecionada.para, kmh: v })
    cenario.atualizacoes.sort((a, b) => a.t - b.t)
    form.hidden = true
    renderLista()
  })

  function renderLista() {
    lista.replaceChildren(...cenario.atualizacoes.map((u, i) => {
      const li = document.createElement("li")
      li.textContent = `t=${u.t}s: ${u.de} → ${u.para} @ ${u.kmh} km/h `
      li.append(botao(t.remove, () => { cenario.atualizacoes.splice(i, 1); renderLista() }))
      return li
    }))
  }

  function aplicar() {
    raiz.__rotas.definirCenario(structuredClone(cenario))
    raiz.__rotas.rodar()
  }

  renderLista()
}
```
Em `montar`, ao fim do `.then` que define o cenário: `if (raiz.hasAttribute("data-rotas-editor")) montarEditor(raiz, canvas, t)`.

- [ ] **Step 3: Testar no navegador**: clicar na via 1→3, aplicar `t=0`, `120 km/h`, "Rodar de novo" → o carro passa a ir por 3 (1500 m a 120 = 45 s; 3→4 48 s; 4→6 60 s = 153 s < 180). "Restaurar cenário" volta ao original. Aplicar velocidade `0` mostra a mensagem de erro sem rodar.

- [ ] **Step 4: `rake check`** → verde.

- [ ] **Step 5: Commit**

```bash
git add frontend/javascript/routes-player.js test/routes_player_test.rb
git commit -m "Editor de transito: muda a velocidade de uma via num instante e roda de novo"
```

---

### Task 9: O texto da página (pt e en)

**Files:**
- Modify: `src/_projects/car-routes.pt.md`, `src/_projects/car-routes.en.md`

**Interfaces:**
- Consumes: os ids de cenário (Task 3). Players inline: `<div class="rotas" data-rotas="<id>"></div>` (sem editor).

- [ ] **Step 1: Confirmar os números** rodando cada cenário no Node (Task 1 Step 7 com `gerarEntrada`): caminho e tempo total de `dijkstra`, `engarrafamento` (240 s, `1 2 5 6`), `tarde-demais`, `via-libera`. Os números do texto abaixo **têm** de bater com o trace; ajustar o texto (não o cenário) se divergirem.

- [ ] **Step 2: Corpo de `car-routes.pt.md`** (substitui "Texto em construção."):

```markdown
Um mapa é um grafo: cruzamentos são nós, vias são arestas com sentido, e
cada via tem um comprimento em metros. O que este trabalho acrescenta é o
tempo: as vias têm velocidade, e a velocidade **muda enquanto o carro anda**
— um engarrafamento às 8h07, uma pista liberada às 8h20. O programa recebe o
mapa, a origem, o destino e a lista de mudanças, e responde por onde ir e
quanto tempo leva.

A simulação acima roda o C original do trabalho, compilado para WebAssembly.
Aperte **Rodar** para ver o algoritmo escolher o caminho, o carro seguir por
ele e, quando a via 2→4 trava, o desvio. Clique em qualquer via para
inventar seu próprio engarrafamento.

## Peso é tempo, não distância

O caminho mais curto não é o mais rápido: 3 km a 60 km/h levam 3 minutos;
4 km a 90 km/h, 2 minutos e 40. Por isso o peso de cada aresta é o tempo
que ela custa, calculado uma vez na leitura do arquivo:

```c
double calculate_weight(double distance, double velocity)
{
    velocity = velocity / 3.6;
    return distance / velocity;
}
```

Metros por (km/h ÷ 3,6) dá segundos. Quando uma via muda de velocidade,
só esse número muda; o grafo continua o mesmo.

## Dijkstra, passo a passo

<div class="rotas" data-rotas="dijkstra"></div>

O Dijkstra mantém, para cada nó, o menor tempo conhecido até ele, e uma
fila dos nós ainda por fechar, ordenada por esse tempo. A cada passo tira
da fila o nó de menor tempo, **fecha** — daqui em diante o tempo dele não
muda mais — e olha os vizinhos: se chegar neles por este nó for mais rápido
do que o que se conhecia, o tempo do vizinho é atualizado e ele volta para
a fila. É o *relaxamento*, e no código é isto:

```c
if (time[w_id] > time[v_id] + value(adj))
{
    time[w_id] = time[v_id] + value(adj);
    dist[w_id] = dist[v_id] + dist(adj);
    path[w_id] = v_id;
    PQ_insert(pq, init_adj(w_id, dist[w_id], time[w_id]));
}
```

`path[w] = v` guarda de onde se chegou em `w`; no fim, andar de trás para
frente a partir do destino reconstrói o caminho. A invariante que faz tudo
funcionar: quando um nó sai da fila, nenhum caminho ainda não explorado
pode ser mais rápido até ele — porque todos os outros nós na fila já custam
mais, e as vias só somam tempo. Isso exige pesos positivos, e tempo sempre
é.

Na simulação, os nós com contorno em destaque estão na fila; os
preenchidos, fechados. Repare que o algoritmo não para ao fechar o destino:
esvazia a fila. É uma otimização que ficou de fora.

## A fila de prioridade

A fila é um heap binário de mínimo (`PQ.c`): inserir e remover custam
O(log n). Sem ele, achar o menor tempo seria uma busca linear a cada passo,
e o algoritmo inteiro sairia em O(V²). Com o heap, O((V + E) log V) — para
um mapa de cidade, a diferença entre segundos e milissegundos.

Um detalhe do trabalho: o heap não tem "diminuir chave" em uso. Quando o
tempo de um nó melhora, ele é inserido de novo, e a cópia antiga fica na
fila com o tempo velho. Ao sair, ela é ignorada porque o nó já foi fechado.
É mais simples e custa pouco: a fila cresce até E entradas em vez de V.

## Quando o trânsito muda

<div class="rotas" data-rotas="engarrafamento"></div>

Aqui está o que o trabalho pede de verdade. O carro sai por `1 2 4 6`, o
plano mais rápido: 3 km, 3 minutos. Aos 30 segundos a via 2→4 cai para
5 km/h. O carro só fica sabendo ao chegar em 2, aos 60 segundos — e aí o
programa aplica a mudança e **roda o Dijkstra de novo, a partir de 2**. A
via 2→4 passou a custar 12 minutos; `2 5 6` custa 3. O carro desvia e chega
em 4 minutos, com 4 km rodados.

O loop que faz isso está em `calculate_path`: anda pelo plano nó a nó
somando tempo; quando o relógio passa do instante da próxima atualização,
aplica todas as vencidas e replaneja de onde está.

<div class="rotas" data-rotas="tarde-demais"></div>

Nem sempre dá tempo. Neste cenário a mesma via trava aos 90 segundos — e o
carro entrou nela aos 60. O modelo não interrompe uma via no meio: a
atualização só é aplicada quando o carro chega ao próximo nó, em 4, aos 120
segundos. Aí já não importa: `4 6` é o único caminho que resta. O trânsito
mudou e o carro pagou por ele sem chance de reagir. É a limitação mais
honesta do modelo, e a mais real.

<div class="rotas" data-rotas="via-libera"></div>

O contrário também acontece. Tudo a 30 km/h, o plano é `1 2 4 6`, 6
minutos. Aos 60 segundos a via 2→5 abre a 120 km/h. O carro chega em 2 aos
2 minutos, replaneja, e `2 5 6` agora custa 2 min 15 contra 4 minutos por
4. Desvia e ganha quase dois minutos.

## O que faria diferente

- **Recalcular do zero** a cada atualização é simples e, para grafos deste
  tamanho, instantâneo. Num mapa real, algoritmos incrementais como D\* Lite
  ou LPA\* reaproveitam a busca anterior e só corrigem o que a mudança
  afetou.
- **O programa lê o futuro**: as atualizações vêm todas no arquivo, com
  instante marcado. Um carro de verdade só sabe do engarrafamento quando ele
  acontece — mas o Dijkstra que ele roda a cada notícia é exatamente este.
- **Uma velocidade inicial só** para todas as vias. Bastaria uma coluna a
  mais no arquivo para cada via ter a sua.
- **O carro não volta**. Se a melhor saída fosse dar meia-volta na via em
  que está, o modelo não sabe.

## Créditos

Trabalho de Técnicas de Busca e Ordenação (UFES, 2023), feito com
[João](https://github.com/vortex2jm) e
[Gabriel Gatti](https://github.com/gabrielgatti7). O código está no
[repositório](https://github.com/viniciuscole/car-routes-optimazing); o
modo *trace* que alimenta estas simulações foi adicionado para esta página.
```

- [ ] **Step 3: `car-routes.en.md`** — a mesma estrutura, traduzida frase a frase para o inglês, com os mesmos `<div class="rotas">` nos mesmos lugares e os mesmos números. Títulos: *Weight is time, not distance* / *Dijkstra, step by step* / *The priority queue* / *When traffic changes* / *What I would do differently* / *Credits*.

- [ ] **Step 4: Ver as duas páginas no navegador** — os quatro players inline montam, cada um com o cenário certo; os blocos `c` têm highlight; nenhum número do texto contradiz o painel ao fim de cada simulação.

- [ ] **Step 5: `rake check`** → verde (o `routes_scenarios_test` confere que todo `data-rotas` do texto existe).

- [ ] **Step 6: Commit**

```bash
git add src/_projects/car-routes.pt.md src/_projects/car-routes.en.md
git commit -m "Escreve a pagina do projeto de rotas com transito"
```

---

### Task 10: Verificação em navegador (`rake routes:verify`)

**Files:**
- Create: `build/routes/verify.js`
- Modify: `Rakefile` (`routes:verify`)

- [ ] **Step 1: `build/routes/verify.js`**

```js
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
```

- [ ] **Step 2: Rakefile** — dentro de `namespace :routes`:

```ruby
  desc "Verifica em navegador de verdade que a simulacao roda na pagina (exige Docker e output/)"
  task :verify do
    saida = File.expand_path("output")
    receita = File.expand_path("build/routes")
    raise "output/ nao existe — rode `bin/bridgetown build` primeiro." unless File.directory?(saida)

    sh "docker run --rm --network host " \
       "--user #{Process.uid}:#{Process.gid} " \
       "-v #{saida}:/site:ro -v #{receita}:/work:ro -w /tmp " \
       "-e ALVO=http://localhost:4124/projects/car-routes/ " \
       "#{IMAGEM_PLAYWRIGHT} " \
       "bash -c 'cp /work/verify.js . && npm install --silent playwright@1.56.0 && " \
       "(python3 -m http.server 4124 --directory /site &) && sleep 2 && node verify.js'"
  end
```
(`IMAGEM_PLAYWRIGHT` já existe no `namespace :demo2d`; mover a constante para o topo do Rakefile se o Ruby reclamar de escopo.)

- [ ] **Step 3: Rodar** `bin/bridgetown build && bundle exec rake routes:verify` → todos `ok`.

- [ ] **Step 4: Commit**

```bash
git add build/routes/verify.js Rakefile
git commit -m "Verifica a simulacao de rotas em navegador de verdade"
```

---

### Task 11: Fechamento e PR

- [ ] **Step 1:** `bundle exec rake check` (Node 22) → verde. `bundle exec rake routes:verify` → verde.
- [ ] **Step 2:** conferir no navegador, nos dois idiomas e nos dois temas, o player principal e os quatro inline; conferir com "reduzir movimento" que nada depende de animação CSS (o canvas é JS, não é afetado).
- [ ] **Step 3:** `git push -u origin car-routes` e PR contra `main`:

```bash
gh pr create --base main --head car-routes --title "Projeto car-routes: Dijkstra replanejado rodando em WebAssembly" --body-file - <<'EOF'
## O que muda

- Novo projeto `car-routes` (pt + en), com texto didatico sobre Dijkstra, fila de prioridade e replanejamento sob atualizacoes de transito.
- O C original do trabalho, compilado para WebAssembly (`build/routes/`, `rake routes:build`, SHA fixo), roda na pagina: cinco players (um com editor de transito) animam a fronteira do Dijkstra, o carro e os desvios.
- Tipo de demo `routes`, partial, textos em pt/en, folha de estilo, cinco modulos JS pequenos com testes `node --test` (novo `rake jstest`, no `check`).
- `rake routes:verify`: Playwright em Docker abre a pagina construida e confirma o caminho final.

Depende de viniciuscole/car-routes-optimazing#<numero do PR trace-mode>.

Spec: `docs/superpowers/specs/2026-09-17-car-routes-design.md`. Planos: `docs/superpowers/plans/2026-09-17-car-routes-{upstream,site}.md`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
```

---

## Self-review

- **Spec Seção 2** (receita, artefatos, teste de tamanho) → Task 1. **3.1** (JSON, quatro cenários, `gerarEntrada`) → Task 3. **3.2** (player, controles, painel, cores por token, carregamento único e sob demanda, noscript) → Tasks 2, 5, 6, 7. **3.3** (editor) → Task 8. **3.4** (partial, `demo.type: routes`) → Task 2. **Seção 4** (front matter, sete seções, players nas posições) → Task 9. **Seção 5** (Ruby: artefatos, cenários coerentes, página nos dois idiomas, `data-rotas` referenciando cenário, bundle contém o player; Playwright) → Tasks 1, 3, 7, 10.
- Nomes: `gerarEntrada`/`chaveAresta` (Task 3) usados em 4, 5, 7, 8; `analisar`/`estadoInicial`/`reduzir`/`duracaoMs` (Task 4) usados em 6 e 7; `criarSimulador`/`carregarScriptNoNavegador` (Task 5) usados em 7; `desenhar`/`posicao`/`arestaMaisProxima` (Task 6) usados em 7 e 8; `raiz.__rotas.{definirCenario, rodar, cenarioAtual}` (Task 7) usados em 8. `data-rotas-*` da Task 2 são os que 7, 8 e 10 leem.
- Ponto de atenção (não é placeholder, é dependência): os números dos cenários `dijkstra`, `tarde-demais` e `via-libera` no texto da Task 9 foram calculados à mão; a Task 9 Step 1 exige confirmá-los contra o trace real antes de publicar.
