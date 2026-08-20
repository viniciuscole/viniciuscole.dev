# Demo jogável do jogo em assembly — Plano de Implementação (Fase 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer o jogo da velha em assembly x86 rodar jogável dentro da página do
projeto, emulado no browser, sem alterar nenhum arquivo existente além do front
matter do projeto.

**Architecture:** O js-dos entra como dependência npm e é copiado para dentro do
site no build, servido da nossa origem. O executável DOS vive num bundle `.jsdos`
de 2 KB versionado, regenerável por uma task que usa Docker. Um partial novo —
`demos/_jsdos.erb` — é tudo que o dispatcher da Fase 1 precisa para o tipo
`jsdos` existir. O emulador só carrega sob clique.

**Tech Stack:** Ruby 3.4.9, Bridgetown 2.2.2, Node 22, js-dos 8.4.1 (backend
DOSBox), NASM, Open Watcom `wlink`, Docker, minitest, rubyzip.

**Spec:** `docs/superpowers/specs/2026-08-17-demo-jogo-fase-2-design.md`

## Global Constraints

- Ruby **3.4.9**, Bridgetown **2.2.2**, **Node 22** (o esbuild do Bridgetown usa `fs.globSync`; com Node 20 o build falha alto, de propósito).
- Toda configuração fica em `config/initializers.rb`. **`bridgetown.config.yml` não existe no Bridgetown 2** — nunca crie um.
- `template_engine "erb"`. Sem Liquid.
- A coleção `projects` usa `permalink "simple"`. Uma página nunca usa `permalink: /` literal.
- A suíte é **`rake check`**. Nunca sobrescreva `rake test`.
- Nenhum texto de interface escrito direto no template: toda string passa por `<%= t("chave") %>`, com a chave presente em **`en.yml` e `pt.yml`**. Um teste reprova se as tabelas divergirem.
- **Zero requisições a terceiros no site publicado.** Vale também para requisições disparadas em tempo de execução pelo JavaScript.
- Backend do emulador: **`dosbox`**, nunca `dosboxX` (1,4 MB contra 7,5 MB).
- **`pathPrefix` é obrigatório** na configuração do js-dos. O padrão dele aponta para a CDN do projeto.
- Sintaxe: `<%= render "partial", chave: valor %>`.
- Commit ao final de cada tarefa, mensagem em português, imperativo.
- Node 22 para rodar a suíte. Se não estiver no PATH, use o binário indicado pelo controlador.

---

### Task 1: Vendorizar o js-dos

Entrega: os arquivos do emulador servidos da nossa origem, com um teste que
reprova se alguém apontar para uma CDN.

**Files:**
- Modify: `package.json` (dependência `js-dos`)
- Modify: `Rakefile` (task `jsdos:vendor`, e ligá-la ao `check`)
- Modify: `.gitignore`
- Create: `test/jsdos_vendor_test.rb`

**Interfaces:**
- Consumes: `ROOT`, `OUTPUT`, `OutputHelpers` (`output`, `assert_page`, `page_body`) de `test/test_helper.rb`
- Produces: os arquivos publicados em `output/vendor/js-dos/` — `js-dos.js`, `js-dos.css`, `emulators/wdosbox.js`, `emulators/wdosbox.wasm`. A Task 4 aponta o `pathPrefix` para `/vendor/js-dos/emulators/`.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/jsdos_vendor_test.rb`:

```ruby
require "test_helper"

class JsdosVendorTest < Minitest::Test
  include OutputHelpers

  VENDOR_FILES = %w[
    vendor/js-dos/js-dos.js
    vendor/js-dos/js-dos.css
    vendor/js-dos/emulators/wdosbox.js
    vendor/js-dos/emulators/wdosbox.wasm
  ].freeze

  def test_emulator_assets_are_published
    VENDOR_FILES.each do |path|
      assert output(path).file?,
        "faltou #{path} em output/ — a task jsdos:vendor rodou?"
    end
  end

  def test_the_wasm_is_the_real_emulator_not_a_stub
    wasm = output("vendor/js-dos/emulators/wdosbox.wasm")
    assert wasm.file?, "wdosbox.wasm nao foi publicado"
    assert wasm.size > 1_000_000,
      "wdosbox.wasm tem #{wasm.size} bytes; o emulador real passa de 1 MB"
  end

  def test_the_heavy_dosboxx_backend_is_not_shipped
    refute output("vendor/js-dos/emulators/wdosbox-x.wasm").exist?,
      "wdosbox-x.wasm (7,5 MB) foi publicado; o projeto usa o backend dosbox"
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL com `faltou vendor/js-dos/js-dos.js em output/`.

- [ ] **Step 3: Instalar o js-dos como dependência**

Run: `npm install js-dos@8.4.1 --save`

Confirme que `package.json` ganhou `"js-dos": "8.4.1"` em `dependencies` (não em
`devDependencies`: é código servido em produção).

- [ ] **Step 4: Ignorar o diretório vendorizado**

Acrescente ao `.gitignore`:

```
src/vendor/
```

O conteúdo vem do npm a cada build; versioná-lo colocaria 1,7 MB de binário no
repositório sem ganho.

- [ ] **Step 5: Criar a task de vendorização**

Acrescente ao `Rakefile`:

```ruby
namespace :jsdos do
  desc "Copia o js-dos do node_modules para src/vendor, servido da nossa origem"
  task :vendor do
    require "fileutils"

    origem = "node_modules/js-dos/dist"
    destino = "src/vendor/js-dos"

    unless Dir.exist?(origem)
      raise "js-dos nao encontrado em #{origem}. Rode `npm install` primeiro."
    end

    FileUtils.rm_rf(destino)
    FileUtils.mkdir_p("#{destino}/emulators")

    FileUtils.cp("#{origem}/js-dos.js", destino)
    FileUtils.cp("#{origem}/js-dos.css", destino)

    # Apenas o backend dosbox. O wdosbox-x tem 7,5 MB e serve para Windows 9x
    # e 3Dfx, nada que este jogo use.
    %w[wdosbox.js wdosbox.wasm].each do |arquivo|
      FileUtils.cp("#{origem}/emulators/#{arquivo}", "#{destino}/emulators/#{arquivo}")
    end
  end
end
```

- [ ] **Step 6: Ligar a vendorização ao `check`**

Na task `check` do `Rakefile`, insira a invocação **antes** do build do site — o
Bridgetown copia `src/vendor` para `output/` durante o build, então vendorizar
depois não teria efeito:

```ruby
task :check => :clean do
  Rake::Task["jsdos:vendor"].invoke
  Rake::Task["frontend:build"].invoke
  sh "bin/bridgetown build"
  Rake::Task["minitest"].invoke
  Rake::Task["proof"].invoke
end
```

- [ ] **Step 7: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — três testes de vendorização verdes.

- [ ] **Step 8: Provar o teste por remoção**

Comente a linha `Rake::Task["jsdos:vendor"].invoke` do `check`, rode
`bundle exec rake check` e confirme que os testes ficam vermelhos nomeando os
arquivos ausentes. Restaure a linha e confirme o verde. Registre a saída.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: vendoriza o js-dos para servir o emulador da nossa origem"
```

---

### Task 2: Bundle `.jsdos` do jogo

Entrega: o executável DOS empacotado e versionado, com a receita reproduzível
que o gerou.

**Files:**
- Create: `build/game/Dockerfile`
- Create: `build/game/dosbox.conf`
- Create: `build/game/build.sh`
- Create: `src/demos/tic-tac-toe/vca.jsdos` (versionado, gerado pela task)
- Modify: `Gemfile` (gem `rubyzip` no grupo `:test`)
- Modify: `Rakefile` (task `game:build`)
- Create: `test/game_bundle_test.rb`

**Interfaces:**
- Consumes: `ROOT`, `OUTPUT`, `OutputHelpers` (Task 1 e Fase 1)
- Produces: o bundle publicado em `output/demos/tic-tac-toe/vca.jsdos`. A Task 3 referencia esse caminho no front matter como `demo.bundle`.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/game_bundle_test.rb`:

```ruby
require "test_helper"
require "zip"

class GameBundleTest < Minitest::Test
  include OutputHelpers

  BUNDLE = "demos/tic-tac-toe/vca.jsdos".freeze

  def test_bundle_is_versioned_in_the_repository
    assert ROOT.join("src", BUNDLE).file?,
      "faltou src/#{BUNDLE} — rode `rake game:build`"
  end

  def test_bundle_is_published
    assert output(BUNDLE).file?, "o bundle nao chegou em output/"
  end

  def test_bundle_carries_the_executable_and_the_dosbox_config
    nomes = Zip::File.open(ROOT.join("src", BUNDLE)) { |zip| zip.map(&:name) }

    assert_includes nomes, "VCA.EXE"
    assert_includes nomes, ".jsdos/dosbox.conf"
  end

  def test_the_packaged_executable_is_a_real_dos_binary
    conteudo = Zip::File.open(ROOT.join("src", BUNDLE)) { |zip| zip.read("VCA.EXE") }

    assert_equal "MZ", conteudo[0, 2],
      "VCA.EXE nao comeca com a assinatura MZ de executavel DOS"
    assert conteudo.bytesize > 3_000,
      "VCA.EXE tem #{conteudo.bytesize} bytes; o esperado passa de 3 KB"
  end

  def test_the_dosbox_config_runs_the_game_on_startup
    conf = Zip::File.open(ROOT.join("src", BUNDLE)) { |zip| zip.read(".jsdos/dosbox.conf") }

    assert_includes conf, "[autoexec]"
    assert_includes conf, "VCA.EXE"
    assert_includes conf, "machine=vgaonly"
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL — primeiro por `cannot load such file -- zip`, depois por
`faltou src/demos/tic-tac-toe/vca.jsdos`.

- [ ] **Step 3: Acrescentar a gem de leitura de zip**

No `Gemfile`, dentro do grupo `:test`:

```ruby
  gem "rubyzip", "~> 2.3"
```

Run: `bundle install`

- [ ] **Step 4: Criar a configuração do DOSBox**

Crie `build/game/dosbox.conf` — é exatamente a configuração validada durante o
design, com o jogo rodando:

```
[dosbox]
machine=vgaonly

[cpu]
cycles=auto

[autoexec]
mount c .
c:
VCA.EXE
```

- [ ] **Step 5: Criar o Dockerfile do toolchain**

Crie `build/game/Dockerfile`:

```dockerfile
FROM debian:bookworm-slim

# nasm monta o assembly; o wlink do Open Watcom liga os .obj num executavel DOS.
# Nao existe ligador para OMF de 16 bits nos repositorios do Debian, por isso o
# Open Watcom vem da release oficial.
#
# O caminho na extracao precisa do prefixo "./": o tarball do Open Watcom grava
# as entradas assim, e `tar ... binl64/wlink` sem o prefixo nao casa nada e o
# build falha.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        nasm curl ca-certificates xz-utils zip git && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/ow.tar.xz \
      https://github.com/open-watcom/open-watcom-v2/releases/download/Current-build/ow-snapshot.tar.xz && \
    mkdir -p /opt/ow && \
    tar xJf /tmp/ow.tar.xz -C /opt/ow ./binl64/wlink && \
    rm /tmp/ow.tar.xz && \
    chmod +x /opt/ow/binl64/wlink

COPY build.sh /usr/local/bin/build-game
RUN chmod +x /usr/local/bin/build-game

ENTRYPOINT ["/usr/local/bin/build-game"]
```

- [ ] **Step 6: Criar o script de build**

Crie `build/game/build.sh`:

```sh
#!/bin/sh
# Monta o jogo e empacota o bundle .jsdos.
#   /src  = fonte do tic-tac-toe-assembly (somente leitura)
#   /conf = dosbox.conf
#   /out  = onde o vca.jsdos e gravado
set -e

echo "montando o assembly..."
nasm -f obj /src/vca.asm -o /tmp/vca.obj
nasm -f obj /src/draw.asm -o /tmp/draw.obj

echo "ligando o executavel DOS..."
cd /tmp
/opt/ow/binl64/wlink format dos file /tmp/vca.obj,/tmp/draw.obj name /tmp/VCA.EXE

echo "empacotando o bundle..."
rm -rf /tmp/bundle
mkdir -p /tmp/bundle/.jsdos
cp /tmp/VCA.EXE /tmp/bundle/VCA.EXE
cp /conf/dosbox.conf /tmp/bundle/.jsdos/dosbox.conf

cd /tmp/bundle
rm -f /out/vca.jsdos
zip -r -X /out/vca.jsdos VCA.EXE .jsdos

echo "pronto:"
ls -l /out/vca.jsdos
```

- [ ] **Step 7: Criar a task `game:build`**

Acrescente ao `Rakefile`:

```ruby
namespace :game do
  desc "Reconstroi o bundle do jogo a partir do fonte em assembly (exige Docker)"
  task :build do
    require "fileutils"
    require "tmpdir"

    repositorio = "https://github.com/viniciuscole/tic-tac-toe-assembly"
    destino = File.expand_path("src/demos/tic-tac-toe")
    receita = File.expand_path("build/game")

    FileUtils.mkdir_p(destino)

    Dir.mktmpdir do |tmp|
      sh "git clone --depth 1 #{repositorio} #{tmp}/assembly"
      sh "docker build -t viniciuscole-game-build #{receita}"
      sh "docker run --rm " \
         "-v #{tmp}/assembly:/src:ro " \
         "-v #{receita}:/conf:ro " \
         "-v #{destino}:/out " \
         "viniciuscole-game-build"
    end
  end
end
```

Esta task **não** entra no `check`: exigiria Docker em toda execução da suíte
para regenerar um artefato de 2 KB que quase nunca muda.

- [ ] **Step 8: Gerar o bundle**

Run: `bundle exec rake game:build`
Expected: o script imprime `pronto:` e um `vca.jsdos` em torno de 2 KB aparece em
`src/demos/tic-tac-toe/`.

- [ ] **Step 9: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — cinco testes de bundle verdes.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: empacota o executavel DOS num bundle jsdos reproduzivel"
```

---

### Task 3: O partial da demo, o front matter e as traduções

Entrega: a página do projeto passa a renderizar a moldura da demo em vez do
placeholder, nos dois idiomas — ainda sem emulador.

**Files:**
- Create: `src/_partials/demos/_jsdos.erb`
- Modify: `src/_projects/tic-tac-toe.en.md` (front matter)
- Modify: `src/_projects/tic-tac-toe.pt.md` (front matter)
- Modify: `src/_locales/en.yml`
- Modify: `src/_locales/pt.yml`
- Create: `test/jsdos_partial_test.rb`

**Interfaces:**
- Consumes: o bundle em `/demos/tic-tac-toe/vca.jsdos` (Task 2); o helper `demo_partial_for(resource)` e a constante `Builders::DemoHelper::DEMO_TYPES` (já contém `jsdos`, da Fase 1)
- Produces: os ganchos de dados que a Task 4 e a Task 5 consomem — `[data-jsdos]` na seção raiz, com `data-bundle` e `data-path-prefix`; `[data-jsdos-frame]`, `[data-jsdos-start]`, `[data-jsdos-screen]`, `[data-jsdos-error]`, `[data-jsdos-keypad]`. Produz as chaves de tradução sob `demo.`.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/jsdos_partial_test.rb`:

```ruby
require "test_helper"

class JsdosPartialTest < Minitest::Test
  include OutputHelpers

  EN = "projects/tic-tac-toe/index.html".freeze
  PT = "pt/projects/tic-tac-toe/index.html".freeze

  def test_the_project_page_renders_the_emulator_demo
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      assert_includes corpo, 'class="demo demo-jsdos"',
        "#{pagina} nao renderizou a demo jsdos"
      refute_includes corpo, 'class="demo demo-none"',
        "#{pagina} ainda mostra o placeholder"
    end
  end

  def test_the_demo_points_at_the_bundle_and_at_our_own_emulator_path
    corpo = page_body(EN)
    assert_includes corpo, 'data-bundle="/demos/tic-tac-toe/vca.jsdos"'
    assert_includes corpo, 'data-path-prefix="/vendor/js-dos/emulators/"'
  end

  def test_the_hooks_the_player_and_keypad_depend_on_exist
    corpo = page_body(EN)
    %w[data-jsdos data-jsdos-frame data-jsdos-start
       data-jsdos-screen data-jsdos-error].each do |gancho|
      assert_includes corpo, gancho, "faltou o gancho #{gancho}"
    end
  end

  # O readme do repositorio do jogo diz "Type OLC ... to play O", mas o codigo
  # compara com 'C' (vca.asm:80) e foi C22 que funcionou nos testes manuais.
  # Este teste impede que alguem "corrija" as instrucoes seguindo o readme.
  def test_the_circle_command_is_documented_as_C
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      assert_includes corpo, "<code>C22</code>",
        "#{pagina} deveria documentar C22 como o comando do circulo"
      refute_includes corpo, "<code>O22</code>",
        "#{pagina} documenta O22, que nao existe no jogo"
    end
  end

  def test_both_locales_render_their_own_instructions
    assert_includes page_body(EN), "Commands"
    assert_includes page_body(PT), "Comandos"
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL com `projects/tic-tac-toe/index.html nao renderizou a demo jsdos`.

- [ ] **Step 3: Acrescentar as chaves de tradução em inglês**

Em `src/_locales/en.yml`, no mesmo nível de `blog:` e `errors:`, acrescente:

```yaml
  demo:
    label: "Playable demo"
    start: "Play the game"
    weight: "Loads a DOS emulator, about 1.7 MB."
    failed: "The emulator could not load. You can still get the game from the repository."
    missing_bundle: "This demo has no bundle configured."
    license: "Emulated with js-dos and DOSBox, both GPL-2.0."
    commands:
      title: "Commands"
      x: "plays X on row 1, column 1"
      c: "plays the circle on row 2, column 2"
      restart: "starts a new game"
      quit: "quits and restores the video mode"
```

- [ ] **Step 4: Acrescentar as chaves de tradução em português**

Em `src/_locales/pt.yml`, no mesmo nível:

```yaml
  demo:
    label: "Demo jogável"
    start: "Jogar"
    weight: "Carrega um emulador de DOS, cerca de 1,7 MB."
    failed: "O emulador não carregou. Você ainda pode pegar o jogo no repositório."
    missing_bundle: "Esta demo não tem bundle configurado."
    license: "Emulado com js-dos e DOSBox, ambos GPL-2.0."
    commands:
      title: "Comandos"
      x: "joga X na linha 1, coluna 1"
      c: "joga o círculo na linha 2, coluna 2"
      restart: "começa uma partida nova"
      quit: "sai e restaura o modo de vídeo"
```

- [ ] **Step 5: Criar o partial**

Crie `src/_partials/demos/_jsdos.erb`:

```erb
<% bundle = resource.data.dig(:demo, :bundle).to_s %>
<section class="demo demo-jsdos"
         data-jsdos
         data-bundle="<%= bundle %>"
         data-path-prefix="/vendor/js-dos/emulators/"
         aria-label="<%= t("demo.label") %>">

  <% if bundle.empty? %>
    <p class="demo-error"><%= t("demo.missing_bundle") %></p>
  <% else %>
    <div class="demo-frame" data-jsdos-frame>
      <button class="demo-start" type="button" data-jsdos-start>
        <%= t("demo.start") %>
      </button>
      <p class="demo-weight"><%= t("demo.weight") %></p>
    </div>

    <div class="demo-screen" data-jsdos-screen hidden></div>

    <p class="demo-error" data-jsdos-error hidden>
      <%= t("demo.failed") %>
      <a href="<%= resource.data.repo %>"><%= resource.data.repo.to_s.sub("https://", "") %></a>
    </p>
  <% end %>

  <div class="demo-instructions">
    <h2><%= t("demo.commands.title") %></h2>
    <ul>
      <li><code>X11</code> — <%= t("demo.commands.x") %></li>
      <li><code>C22</code> — <%= t("demo.commands.c") %></li>
      <li><code>c</code> — <%= t("demo.commands.restart") %></li>
      <li><code>s</code> — <%= t("demo.commands.quit") %></li>
    </ul>
  </div>

  <p class="demo-license">
    <%= t("demo.license") %>
    <a href="https://github.com/caiiiycuk/js-dos">js-dos</a>
  </p>
</section>
```

O `bundle.empty?` é o mesmo cuidado que a Fase 1 aplicou ao `demo.type`: front
matter ausente ou malformado degrada para uma mensagem, nunca derruba o build.

- [ ] **Step 6: Ligar a demo no front matter dos dois idiomas**

Em `src/_projects/tic-tac-toe.en.md` **e** `src/_projects/tic-tac-toe.pt.md`,
substitua o bloco `demo:` por:

```yaml
demo:
  type: jsdos
  bundle: /demos/tic-tac-toe/vca.jsdos
```

- [ ] **Step 7: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — cinco testes de partial verdes.

- [ ] **Step 8: Provar o teste do comando por remoção**

Troque `<code>C22</code>` por `<code>O22</code>` no partial, rode
`bundle exec rake check` e confirme que o teste do comando fica vermelho.
Restaure e confirme o verde. Registre a saída — este teste existe para impedir
uma regressão específica e precisa provar que morde.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: renderiza a moldura da demo na pagina do projeto"
```

---

### Task 4: O player, carregado sob clique

Entrega: o emulador liga ao clique, servido da nossa origem, sem interface de
terceiro na tela.

**Files:**
- Create: `frontend/javascript/jsdos-player.js`
- Modify: `frontend/javascript/index.js` (importar o player)
- Create: `test/jsdos_player_test.rb`

**Interfaces:**
- Consumes: os ganchos `[data-jsdos]`, `[data-bundle]`, `[data-path-prefix]`, `[data-jsdos-frame]`, `[data-jsdos-start]`, `[data-jsdos-screen]`, `[data-jsdos-error]` (Task 3); os arquivos em `/vendor/js-dos/` (Task 1)
- Produces: a função exportada `bootJsdos(root)`, e o `CommandInterface` do js-dos guardado em `root.__ci` quando o evento `ci-ready` chega — é dele que a Task 5 envia as teclas.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/jsdos_player_test.rb`:

```ruby
require "test_helper"

class JsdosPlayerTest < Minitest::Test
  include OutputHelpers

  # Apenas o JavaScript que nos escrevemos. O js-dos vendorizado e codigo de
  # terceiro e contem a URL da CDN dele como padrao — o que importa e que o
  # NOSSO codigo sobrescreva esse padrao.
  def nosso_javascript
    Dir.glob(OUTPUT.join("_bridgetown/static/*.js"))
  end

  def test_our_javascript_is_published
    refute_empty nosso_javascript, "nenhum bundle JavaScript foi gerado"
  end

  def test_the_player_overrides_the_emulator_path
    encontrou = nosso_javascript.any? do |arquivo|
      File.read(arquivo).include?("/vendor/js-dos/emulators/")
    end

    assert encontrou,
      "o pathPrefix nao aparece no JavaScript publicado; sem ele o js-dos " \
      "baixa o emulador da CDN dele"
  end

  # Le o FONTE. No bundle minificado a palavra "dosbox" ja aparece dentro do
  # pathPrefix, entao procura-la la passaria mesmo sem o backend configurado.
  def test_the_player_asks_for_the_light_dosbox_backend
    fonte = ROOT.join("frontend/javascript/jsdos-player.js").read

    assert_match(/backend:\s*"dosbox"/, fonte,
      "o player precisa pedir o backend dosbox explicitamente")
    refute_match(/backend:\s*"dosboxX"/, fonte,
      "o backend dosboxX tem 7,5 MB e nao e usado por este projeto")
  end

  def test_the_player_hides_the_third_party_ui
    fonte = ROOT.join("frontend/javascript/jsdos-player.js").read

    assert_match(/kiosk:\s*true/, fonte,
      "sem kiosk o js-dos desenha a interface dele por cima da nossa moldura")
  end

  def test_our_javascript_makes_no_third_party_requests
    nosso_javascript.each do |arquivo|
      urls = File.read(arquivo).scan(%r{https?://[^\s"'`)]+})
      externas = urls.reject { |u| u.start_with?("http://www.w3.org/") }

      assert_empty externas.uniq,
        "#{File.basename(arquivo)} referencia URL externa: #{externas.uniq.first(3).join(', ')}"
    end
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL com `o pathPrefix nao aparece no JavaScript publicado`.

- [ ] **Step 3: Escrever o player**

Crie `frontend/javascript/jsdos-player.js`:

```javascript
// Carrega o emulador js-dos sob demanda. Nada e baixado ate o visitante
// clicar: sao cerca de 1,7 MB, e quem so veio ler sobre o projeto nao paga
// essa conta.

const SCRIPT = "/vendor/js-dos/js-dos.js"
const ESTILOS = "/vendor/js-dos/js-dos.css"

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
      pathPrefix: root.dataset.pathPrefix,
      backend: "dosbox",
      // Esconde a interface propria do js-dos. Quem enquadra o jogo e o site.
      kiosk: true,
      imageRendering: "pixelated",
      autoStart: true,
      onEvent: (evento, ci) => {
        if (evento === "ci-ready") {
          root.__ci = ci
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
```

- [ ] **Step 4: Importar o player**

Em `frontend/javascript/index.js`, acrescente no topo, junto dos demais imports:

```javascript
import "./jsdos-player.js"
```

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — quatro testes de player verdes.

- [ ] **Step 6: Verificar no navegador, e ser honesto sobre isso**

A suíte não consegue provar que o emulador roda: falta navegador headless na
máquina. Faça a verificação manual e registre o que observou.

Run: `bin/bridgetown start`
Abra a página do projeto, clique em jogar, e confirme: o emulador aparece, a
interface do js-dos **não** aparece (kiosk), o jogo desenha o tabuleiro, e
digitar `X11` seguido de Enter desenha o X.

Confirme na aba de rede do navegador que **nenhuma requisição sai para
`js-dos.com`**. Esse é o ponto que nenhum teste automatizado cobre.

Se o callback `onEvent` não entregar o `ci-ready` com a assinatura suposta,
descubra a assinatura real inspecionando o objeto e corrija — o nome da API foi
verificado no fonte do js-dos, a forma do callback não. Relate o que encontrou.

Enquanto estiver com a página aberta, responda também: **o `js-dos.css` de 118 KB
ainda é necessário em modo kiosk?** Ele existe sobretudo para a interface que o
kiosk esconde. Teste removendo o `<link>` e recarregando: se a tela do jogo
continuar correta, deixe de servi-lo e remova-o da task `jsdos:vendor` — são
118 KB por visita que ninguém usa. Se algo quebrar, mantenha e diga o que
quebrou. Não decida isso por dedução; teste.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: liga o emulador sob clique, servido da nossa origem"
```

---

### Task 5: Teclado na tela

Entrega: o jogo jogável sem teclado físico, que é o que torna a demo utilizável
no celular.

**Files:**
- Create: `frontend/javascript/jsdos-keypad.js`
- Modify: `src/_partials/demos/_jsdos.erb` (marcação do teclado)
- Modify: `src/_locales/en.yml`, `src/_locales/pt.yml`
- Modify: `frontend/javascript/jsdos-player.js` (montar o teclado quando pronto)
- Create: `test/jsdos_keypad_test.rb`

**Interfaces:**
- Consumes: `root.__ci` e o evento `jsdos:ready` (Task 4); os ganchos do partial (Task 3)
- Produces: a função exportada `montarTeclado(root, ci)`

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/jsdos_keypad_test.rb`:

```ruby
require "test_helper"

class JsdosKeypadTest < Minitest::Test
  include OutputHelpers

  EN = "projects/tic-tac-toe/index.html".freeze
  PT = "pt/projects/tic-tac-toe/index.html".freeze

  def test_the_keypad_is_rendered_in_both_locales
    [EN, PT].each do |pagina|
      assert_includes page_body(pagina), "data-jsdos-keypad",
        "#{pagina} nao tem o teclado na tela"
    end
  end

  def test_the_keypad_offers_every_cell_of_the_board
    corpo = page_body(EN)
    (1..3).each do |linha|
      (1..3).each do |coluna|
        assert_includes corpo, %(data-cell="#{linha}#{coluna}"),
          "faltou o botao da celula #{linha}#{coluna}"
      end
    end
  end

  def test_the_keypad_labels_come_from_the_locales
    assert_includes page_body(EN), "Restart"
    assert_includes page_body(PT), "Reiniciar"
  end

  # Le o FONTE, nao o bundle minificado. Procurar "49" no bundle passaria
  # sempre: numeros curtos aparecem em qualquer JavaScript minificado, e o
  # teste ficaria verde mesmo com o mapa de teclas errado.
  def test_the_key_codes_are_the_ones_js_dos_expects
    fonte = ROOT.join("frontend/javascript/jsdos-keypad.js").read

    # Constantes KBD_* do js-dos: ASCII maiusculo para letras e digitos,
    # codigos proprios acima de 256 para teclas especiais.
    {
      "X" => 88, "C" => 67, "S" => 83,
      "1" => 49, "2" => 50, "3" => 51,
      "enter" => 257,
    }.each do |tecla, codigo|
      assert_match(/#{Regexp.escape(tecla)}:\s*#{codigo}\b/, fonte,
        "o mapa de teclas deveria associar #{tecla} ao codigo #{codigo} do js-dos")
    end
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL com `projects/tic-tac-toe/index.html nao tem o teclado na tela`.

- [ ] **Step 3: Acrescentar as chaves de tradução**

Em `src/_locales/en.yml`, dentro de `demo:`:

```yaml
    keypad:
      title: "On-screen controls"
      mark_x: "Play X"
      mark_c: "Play circle"
      restart: "Restart"
      quit: "Quit"
      cell: "Row %{row}, column %{column}"
```

Em `src/_locales/pt.yml`, dentro de `demo:`:

```yaml
    keypad:
      title: "Controles na tela"
      mark_x: "Jogar X"
      mark_c: "Jogar círculo"
      restart: "Reiniciar"
      quit: "Sair"
      cell: "Linha %{row}, coluna %{column}"
```

- [ ] **Step 4: Acrescentar a marcação do teclado ao partial**

Em `src/_partials/demos/_jsdos.erb`, logo antes de `<div class="demo-instructions">`:

```erb
    <div class="demo-keypad" data-jsdos-keypad hidden>
      <h3><%= t("demo.keypad.title") %></h3>

      <div class="keypad-marks">
        <button type="button" data-mark="X"><%= t("demo.keypad.mark_x") %></button>
        <button type="button" data-mark="C"><%= t("demo.keypad.mark_c") %></button>
      </div>

      <div class="keypad-grid">
        <% (1..3).each do |linha| %>
          <% (1..3).each do |coluna| %>
            <button type="button"
                    data-cell="<%= linha %><%= coluna %>"
                    aria-label="<%= t("demo.keypad.cell", row: linha, column: coluna) %>">
              <%= linha %><%= coluna %>
            </button>
          <% end %>
        <% end %>
      </div>

      <div class="keypad-actions">
        <button type="button" data-action="restart"><%= t("demo.keypad.restart") %></button>
        <button type="button" data-action="quit"><%= t("demo.keypad.quit") %></button>
      </div>
    </div>
```

- [ ] **Step 5: Escrever o teclado**

Crie `frontend/javascript/jsdos-keypad.js`:

```javascript
// Traduz cliques em teclas para o emulador. O jogo so aceita comandos
// digitados, entao sem isso a demo e injogavel no celular.
//
// Os codigos sao as constantes KBD_* do js-dos, extraidas do bundle dele:
// letras e digitos usam o valor ASCII maiusculo, teclas especiais usam
// codigos proprios acima de 256.

const TECLAS = {
  X: 88,
  C: 67,
  S: 83,
  1: 49,
  2: 50,
  3: 51,
  enter: 257,
}

// Marca escolhida no teclado. O jogo alterna os jogadores sozinho, mas o
// comando precisa dizer qual simbolo esta sendo jogado.
let marcaAtual = "X"

export function montarTeclado(root, ci) {
  const teclado = root.querySelector("[data-jsdos-keypad]")
  if (!teclado || !ci) return

  teclado.hidden = false

  teclado.querySelectorAll("[data-mark]").forEach((botao) => {
    botao.addEventListener("click", () => {
      marcaAtual = botao.dataset.mark
      teclado.querySelectorAll("[data-mark]").forEach((outro) => {
        outro.setAttribute("aria-pressed", String(outro === botao))
      })
    })
  })

  teclado.querySelectorAll("[data-cell]").forEach((botao) => {
    botao.addEventListener("click", () => {
      const [linha, coluna] = botao.dataset.cell.split("")
      ci.simulateKeyPress(TECLAS[marcaAtual], TECLAS[linha], TECLAS[coluna])
      ci.simulateKeyPress(TECLAS.enter)
    })
  })

  teclado.querySelectorAll("[data-action]").forEach((botao) => {
    botao.addEventListener("click", () => {
      // 'c' reinicia e 's' sai; o jogo aceita as duas em minusculo, e o
      // emulador nao distingue caixa no codigo da tecla.
      const tecla = botao.dataset.action === "restart" ? TECLAS.C : TECLAS.S
      ci.simulateKeyPress(tecla)
      ci.simulateKeyPress(TECLAS.enter)
    })
  })
}
```

- [ ] **Step 6: Montar o teclado quando o emulador ficar pronto**

Em `frontend/javascript/jsdos-player.js`, acrescente o import no topo:

```javascript
import { montarTeclado } from "./jsdos-keypad.js"
```

E dentro do `onEvent`, logo após `root.__ci = ci`:

```javascript
          montarTeclado(root, ci)
```

- [ ] **Step 7: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — quatro testes de teclado verdes.

- [ ] **Step 8: Verificar no navegador**

Run: `bin/bridgetown start`
Clique em jogar, espere o emulador, escolha `X`, clique na célula `11` e confirme
que o X aparece no tabuleiro. Depois escolha o círculo e clique em `22`.

Se as jogadas não registrarem, o problema é a forma da chamada, não o código da
tecla — os códigos foram extraídos do próprio js-dos. Inspecione o objeto `ci`
para achar a assinatura correta e corrija. Relate o que encontrou.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: teclado na tela para o jogo ser jogavel sem teclado fisico"
```

---

### Task 6: Tratamento visual CRT

Entrega: a página do jogo com identidade própria, sem contaminar o resto do site.

**Files:**
- Create: `frontend/styles/crt.css`
- Modify: `frontend/styles/index.css` (importar)
- Create: `test/crt_test.rb`

**Interfaces:**
- Consumes: os tokens `--vga-green`, `--vga-cyan`, `--vga-amber`, `--bg`, `--fg`, `--border`, `--font-mono` de `frontend/styles/tokens.css` (Fase 1); as classes emitidas pelo partial (Task 3 e 5)
- Produces: nenhuma interface consumida por outra tarefa

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/crt_test.rb`:

```ruby
require "test_helper"

class CrtTest < Minitest::Test
  include OutputHelpers

  def css
    ROOT.join("frontend/styles/crt.css").read
  end

  def test_the_crt_stylesheet_exists
    assert ROOT.join("frontend/styles/crt.css").file?
  end

  def test_every_class_the_demo_emits_has_styling
    %w[.demo-jsdos .demo-frame .demo-start .demo-weight .demo-screen
       .demo-error .demo-instructions .demo-license
       .demo-keypad .keypad-grid .keypad-marks .keypad-actions].each do |classe|
      assert_includes css, classe, "a classe #{classe} e emitida mas nao tem estilo"
    end
  end

  def test_it_reuses_the_palette_instead_of_inventing_colours
    assert_includes css, "var(--vga-", "o CRT deveria usar os tokens VGA existentes"
  end

  def test_animation_respects_reduced_motion
    assert_includes css, "prefers-reduced-motion",
      "o tratamento CRT precisa desligar animacao para quem pede menos movimento"
  end

  def test_the_stylesheet_is_imported
    assert_includes ROOT.join("frontend/styles/index.css").read, "crt.css"
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL — `frontend/styles/crt.css` não existe.

- [ ] **Step 3: Escrever o CSS**

Crie `frontend/styles/crt.css`:

```css
/* Tratamento CRT, restrito a pagina do jogo. O resto do site permanece
   moderno e limpo — e isso que faz o retro parecer intencional. */

.demo-jsdos {
  --crt-phosphor: var(--vga-green);
  margin: calc(var(--space) * 2) 0;
}

.demo-frame,
.demo-screen {
  aspect-ratio: 4 / 3;           /* a proporcao do modo VGA 12h, 640x480 */
  width: 100%;
  background: #000;
  border: 2px solid var(--border);
  border-radius: 10px;
  box-shadow: inset 0 0 60px rgba(0, 0, 0, 0.9);
}

.demo-frame {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
}

.demo-start {
  background: transparent;
  border: 1px solid var(--crt-phosphor);
  border-radius: var(--radius);
  color: var(--crt-phosphor);
  cursor: pointer;
  font-family: var(--font-mono);
  font-size: 1rem;
  padding: 0.5rem 1.25rem;
}

.demo-start:hover,
.demo-start:focus-visible {
  background: var(--crt-phosphor);
  color: #000;
}

.demo-weight,
.demo-license {
  color: var(--muted);
  font-family: var(--font-mono);
  font-size: 0.8125rem;
}

.demo-weight { margin: 0; }

.demo-screen canvas {
  image-rendering: pixelated;    /* pixels quadrados, como no VGA */
  width: 100%;
  height: 100%;
}

.demo-error {
  border: 1px solid var(--vga-amber);
  border-radius: var(--radius);
  color: var(--vga-amber);
  font-family: var(--font-mono);
  padding: var(--space);
}

.demo-instructions ul {
  list-style: none;
  padding: 0;
}

.demo-instructions li {
  font-family: var(--font-mono);
  font-size: 0.875rem;
  padding: 0.125rem 0;
}

.demo-instructions code {
  color: var(--crt-phosphor);
}

.demo-keypad {
  border: 1px solid var(--border);
  border-radius: var(--radius);
  margin-top: var(--space);
  padding: var(--space);
}

.keypad-grid {
  display: grid;
  gap: 0.5rem;
  grid-template-columns: repeat(3, minmax(3rem, 5rem));
}

.keypad-marks,
.keypad-actions {
  display: flex;
  gap: 0.5rem;
  margin: 0.5rem 0;
}

.demo-keypad button {
  background: transparent;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--fg);
  cursor: pointer;
  font-family: var(--font-mono);
  min-height: 2.75rem;           /* alvo de toque confortavel no celular */
  padding: 0.5rem;
}

.demo-keypad button:hover,
.demo-keypad button:focus-visible {
  border-color: var(--crt-phosphor);
  color: var(--crt-phosphor);
}

.demo-keypad button[aria-pressed="true"] {
  background: var(--crt-phosphor);
  border-color: var(--crt-phosphor);
  color: #000;
}

/* A vinheta e o unico efeito puramente decorativo; some para quem pede
   menos movimento ou prefere menos ruido visual. */
@media (prefers-reduced-motion: no-preference) {
  .demo-screen::after {
    background: radial-gradient(ellipse at center,
                transparent 60%, rgba(0, 0, 0, 0.35) 100%);
    content: "";
    inset: 0;
    pointer-events: none;
    position: absolute;
  }

  .demo-screen { position: relative; }
}

@media (min-width: 60rem) {
  .demo-jsdos {
    align-items: start;
    display: grid;
    gap: calc(var(--space) * 1.5);
    grid-template-columns: 3fr 2fr;
  }

  .demo-frame,
  .demo-screen { grid-column: 1; }
  .demo-keypad,
  .demo-instructions { grid-column: 2; }
  .demo-license { grid-column: 1 / -1; }
}
```

- [ ] **Step 4: Importar a folha de estilo**

Em `frontend/styles/index.css`, junto dos demais `@import`:

```css
@import "./crt.css";
```

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — cinco testes de CRT verdes.

- [ ] **Step 6: Verificar no navegador**

Run: `bin/bridgetown start`
Confirme na página do projeto: a moldura tem proporção 4:3, o botão de jogar
aparece centralizado, e em tela larga o teclado e as instruções ficam ao lado do
emulador. Estreite a janela e confirme que descem para baixo.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: tratamento CRT na pagina do jogo, sem contaminar o site"
```

---

## Critérios de conclusão da Fase 2

- A página do projeto tem o jogo jogável, carregado sob clique
- Nenhuma requisição sai para a CDN do js-dos — verificado na aba de rede
- A interface do js-dos não aparece; quem enquadra o jogo é o site
- O teclado na tela joga uma partida sem teclado físico
- Adicionar a demo não exigiu alterar nenhum arquivo existente além do front
  matter do projeto e do import do player — a promessa da Fase 1 se confirma
- `rake check` verde, incluindo html-proofer
