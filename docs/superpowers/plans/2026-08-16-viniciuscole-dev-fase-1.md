# viniciuscole.dev Fase 1 — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Colocar `viniciuscole.dev` no ar — site pessoal bilíngue com blog e uma
coleção de projetos onde adicionar um projeto novo é escrever dois arquivos
Markdown.

**Architecture:** Site estático gerado por Bridgetown 2 (Ruby/ERB). Os projetos
são uma coleção de recursos Markdown; cada página de projeto delega o bloco de
demo a um partial escolhido em tempo de build por um helper, que é o ponto de
extensão para demos futuras. O build roda no GitHub Actions e publica o
diretório `output/` no Cloudflare Pages via wrangler.

**Tech Stack:** Ruby 3.4.9, Bridgetown 2.2.2, ERB, gem I18n, minitest,
html-proofer, esbuild, PostCSS, GitHub Actions, Cloudflare Pages.

**Spec:** `docs/superpowers/specs/2026-08-16-viniciuscole-dev-site-design.md`

## Global Constraints

Valem para todas as tarefas; não repita, mas não viole.

- Ruby **3.4.9**, Bridgetown **2.2.2**.
- Toda configuração fica em `config/initializers.rb`. **Não existe
  `bridgetown.config.yml` no Bridgetown 2** — não crie um.
- `template_engine "erb"`. Sem Liquid.
- `available_locales [:en, :pt]`, `default_locale :en`,
  `prefix_default_locale false`.
- A coleção `projects` usa **`permalink "simple"`**. Nunca troque por uma string
  customizada: um permalink customizado ignora o prefixo de locale e faz as duas
  traduções gravarem no mesmo arquivo — uma sobrescreve a outra em silêncio, sem
  erro no build. Isso foi verificado na prática, não é teoria.
- A suíte de testes é **`rake check`**. Não sobrescreva `rake test`: o Rakefile
  do Bridgetown já usa esse nome para "construir no ambiente de teste".
- Nenhum texto de interface fica escrito direto no template. Toda string passa
  por `<%= t("chave") %>`, com a chave presente em `en.yml` **e** `pt.yml`.
- Todo **projeto** existe nos dois idiomas. Um **post** pode existir em um só.
- Zero requisições a terceiros no site publicado: fontes auto-hospedadas, sem
  CDN, sem Google Fonts, sem analytics.
- Sintaxe de renderização: `<%= render "nome_do_partial", chave: valor %>` para
  partials, `<%= render Componente.new(...) %>` para componentes Ruby.
- Commit ao final de cada tarefa. Mensagens em português, imperativo.

---

### Task 1: Scaffold do projeto e suíte `rake check`

Entrega: um site Bridgetown que constrói, com um runner de testes funcionando.
Todas as tarefas seguintes dependem deste harness.

**Files:**
- Create: todo o scaffold do Bridgetown na raiz do repositório
- Create: `test/test_helper.rb`
- Create: `test/output_structure_test.rb`
- Modify: `Rakefile` (acrescentar a tarefa `check`)
- Modify: `Gemfile` (acrescentar minitest)

**Interfaces:**
- Consumes: nada (primeira tarefa)
- Produces: constante `OUTPUT` (`Pathname` para `output/`), constante `ROOT`
  (`Pathname` da raiz do repo) e módulo `OutputHelpers` com os métodos
  `output(path) -> Pathname` e `assert_page(path)`. Todas as tarefas seguintes
  usam esses nomes nos testes.

- [ ] **Step 1: Gerar o scaffold na raiz do repositório**

O repositório já existe e contém `docs/`, mas o gerador do Bridgetown exige um
diretório vazio. Gere fora e traga o conteúdo para dentro:

```bash
REPO="$(git rev-parse --show-toplevel)"
SCAFFOLD="$(mktemp -d)/site"

bridgetown new "$SCAFFOLD" --templates=erb

# copia tudo, inclusive arquivos ocultos como .gitignore e .ruby-version
cp -a "$SCAFFOLD/." "$REPO/"

cd "$REPO"
```

O scaffold não cria `.git`, então não há risco de sobrescrever o histórico do
repositório.

Confira que chegaram: `config/initializers.rb`, `Rakefile`, `Gemfile`,
`package.json`, `plugins/site_builder.rb`, `src/_layouts/default.erb` e
`frontend/styles/index.css`.

Run: `bundle install && npm install`

- [ ] **Step 2: Escrever o helper de testes**

Crie `test/test_helper.rb`:

```ruby
require "minitest/autorun"
require "pathname"
require "yaml"
require "date" # YAML.safe_load precisa de Date liberado para ler front matter

ROOT   = Pathname.new(File.expand_path("..", __dir__))
OUTPUT = ROOT.join("output")

module OutputHelpers
  # Caminho absoluto de um arquivo dentro de output/
  def output(path)
    OUTPUT.join(path)
  end

  # Falha com mensagem util quando a pagina esperada nao foi gerada
  def assert_page(path)
    assert output(path).file?,
      "esperava a pagina #{path} dentro de output/, mas ela nao foi gerada"
  end

  # Conteudo HTML de uma pagina gerada
  def page_body(path)
    assert_page(path)
    output(path).read
  end
end
```

- [ ] **Step 3: Escrever o teste que falha**

Crie `test/output_structure_test.rb`:

```ruby
require "test_helper"

class OutputStructureTest < Minitest::Test
  include OutputHelpers

  def test_home_is_generated
    assert_page "index.html"
  end
end
```

- [ ] **Step 4: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL com `Don't know how to build task 'check'` — a tarefa ainda não
existe. Essa é a falha esperada nesta etapa.

- [ ] **Step 5: Acrescentar minitest ao Gemfile**

Acrescente ao `Gemfile`:

```ruby
group :test do
  gem "minitest", "~> 5.25"
end
```

Run: `bundle install`

- [ ] **Step 6: Acrescentar a tarefa `check` ao Rakefile**

Acrescente ao final do `Rakefile` (não altere a tarefa `test` existente):

```ruby
require "rake/testtask"

Rake::TestTask.new(:minitest) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

desc "Constroi o site e roda todas as verificacoes"
task :check do
  sh "bin/bridgetown build"
  Rake::Task["minitest"].invoke
end
```

- [ ] **Step 7: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — o build gera `output/index.html` e o teste encontra a página.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: scaffold do site Bridgetown e suite rake check"
```

---

### Task 2: Bilíngue inglês/português

Entrega: o site gera as duas versões de idioma, com traduções resolvidas por
locale e uma trava que impede as tabelas de tradução divergirem.

**Files:**
- Modify: `config/initializers.rb`
- Create: `src/_locales/en.yml`
- Create: `src/_locales/pt.yml`
- Delete: `src/index.md`
- Create: `src/index.en.md`
- Create: `src/index.pt.md`
- Create: `test/locales_test.rb`

**Interfaces:**
- Consumes: `OutputHelpers`, `ROOT`, `output`, `assert_page`, `page_body` (Task 1)
- Produces: as chaves de tradução `site.title`, `site.tagline`, `nav.home`,
  `nav.projects`, `nav.blog`, `nav.language`, `locale.en`, `locale.pt`,
  disponíveis via `t("chave")` em qualquer template. Produz também o método
  privado de teste `flatten_keys(hash, prefix = nil) -> Array<String>`.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/locales_test.rb`:

```ruby
require "test_helper"

class LocalesTest < Minitest::Test
  include OutputHelpers

  def test_both_home_pages_are_generated
    assert_page "index.html"
    assert_page "pt/index.html"
  end

  def test_html_lang_attribute_matches_the_locale
    assert_includes page_body("index.html"), 'lang="en"'
    assert_includes page_body("pt/index.html"), 'lang="pt"'
  end

  def test_translations_resolve_per_locale
    assert_includes page_body("index.html"), "Projects"
    assert_includes page_body("pt/index.html"), "Projetos"
  end

  def test_locale_tables_have_identical_key_sets
    en = flatten_keys(YAML.load_file(ROOT.join("src/_locales/en.yml")).fetch("en"))
    pt = flatten_keys(YAML.load_file(ROOT.join("src/_locales/pt.yml")).fetch("pt"))

    assert_equal [], en - pt,
      "chaves presentes em en.yml e ausentes em pt.yml: #{(en - pt).join(', ')}"
    assert_equal [], pt - en,
      "chaves presentes em pt.yml e ausentes em en.yml: #{(pt - en).join(', ')}"
  end

  private

  # ["nav.home", "nav.projects", ...] a partir de um hash aninhado
  def flatten_keys(hash, prefix = nil)
    hash.flat_map do |key, value|
      full = [prefix, key].compact.join(".")
      value.is_a?(Hash) ? flatten_keys(value, full) : [full]
    end.sort
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL — `esperava a pagina pt/index.html dentro de output/, mas ela nao
foi gerada`, e erro de arquivo inexistente em `src/_locales/en.yml`.

- [ ] **Step 3: Configurar os locales**

Em `config/initializers.rb`, logo abaixo de `template_engine "erb"`, insira:

```ruby
  available_locales [:en, :pt]
  default_locale :en
  prefix_default_locale false
```

- [ ] **Step 4: Criar as tabelas de tradução**

Crie `src/_locales/en.yml`:

```yaml
en:
  site:
    title: "Vinicius Cole"
    tagline: "Software developer"
  nav:
    home: "Home"
    projects: "Projects"
    blog: "Blog"
    language: "Language"
  locale:
    en: "English"
    pt: "Português"
```

Crie `src/_locales/pt.yml`:

```yaml
pt:
  site:
    title: "Vinicius Cole"
    tagline: "Desenvolvedor de software"
  nav:
    home: "Início"
    projects: "Projetos"
    blog: "Blog"
    language: "Idioma"
  locale:
    en: "English"
    pt: "Português"
```

- [ ] **Step 5: Criar as home pages por idioma**

Apague `src/index.md`. Crie `src/index.en.md`:

```markdown
---
layout: page
title: Vinicius Cole
locale: en
---

<%= t("nav.projects") %>
```

Crie `src/index.pt.md`:

```markdown
---
layout: page
title: Vinicius Cole
locale: pt
---

<%= t("nav.projects") %>
```

O corpo é provisório: serve só para o teste provar que a tradução resolve por
locale. A Task 6 substitui por conteúdo real.

- [ ] **Step 6: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — quatro testes de locale verdes.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: suporte bilingue ingles/portugues com trava de paridade de chaves"
```

---

### Task 3: Layout base, navegação e alternador de idioma

Entrega: o shell visual do site — cabeçalho com navegação traduzida, alternador
de idioma que nunca gera link quebrado, e rodapé com os links de contato vindos
de uma fonte única.

**Files:**
- Create: `src/_data/site_links.yml`
- Create: `plugins/builders/site_helpers.rb`
- Create: `src/_partials/_header.erb`
- Create: `src/_partials/_locale_switcher.erb`
- Modify: `src/_partials/_footer.erb`
- Modify: `src/_layouts/default.erb`
- Create: `test/layout_test.rb`

**Interfaces:**
- Consumes: chaves `nav.*` e `locale.*` (Task 2); `OutputHelpers` (Task 1)
- Produces: o helper `locale_home_url(locale) -> String`, disponível em qualquer
  template. Produz o partial `_locale_switcher.erb`, que espera o local
  `resource:`. Produz `site.data.site_links`, um hash com as chaves `github`,
  `linkedin` e `email`.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/layout_test.rb`:

```ruby
require "test_helper"

class LayoutTest < Minitest::Test
  include OutputHelpers

  def test_english_home_links_to_the_portuguese_translation
    assert_includes page_body("index.html"), 'href="/pt/"'
  end

  def test_portuguese_home_links_to_the_english_translation
    assert_includes page_body("pt/index.html"), 'href="/"'
  end

  def test_switcher_omits_the_current_locale
    # a home em ingles nao deve oferecer "English" como destino
    body = page_body("index.html")
    switcher = body[/<nav class="locale-switcher".*?<\/nav>/m]
    refute_nil switcher, "alternador de idioma nao encontrado na home"
    refute_includes switcher, "English"
    assert_includes switcher, "Português"
  end

  def test_navigation_is_translated
    assert_includes page_body("index.html"), "Blog"
    assert_includes page_body("pt/index.html"), "Início"
  end

  def test_footer_shows_the_contact_links
    body = page_body("index.html")
    assert_includes body, "https://github.com/viniciuscole"
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL — `alternador de idioma nao encontrado na home`.

- [ ] **Step 3: Criar a fonte única dos links de contato**

Crie `src/_data/site_links.yml`:

```yaml
github: "https://github.com/viniciuscole"
linkedin: "https://www.linkedin.com/in/viniciuscole"
email: "mailto:vinicius.amorim@v360.io"
```

Se algum desses endereços estiver errado, corrija aqui — este é o único lugar
onde eles aparecem.

- [ ] **Step 4: Criar o helper de URL de home por idioma**

Crie `plugins/builders/site_helpers.rb`:

```ruby
class Builders::SiteHelpers < SiteBuilder
  def build
    # Destino de fallback do alternador quando a traducao nao existe
    helper :locale_home_url do |locale|
      if locale.to_s == site.config.default_locale.to_s
        "/"
      else
        "/#{locale}/"
      end
    end
  end
end
```

- [ ] **Step 5: Criar o alternador de idioma**

Crie `src/_partials/_locale_switcher.erb`:

```erb
<nav class="locale-switcher" aria-label="<%= t("nav.language") %>">
  <% site.config.available_locales.each do |locale| %>
    <% next if locale.to_s == resource.data.locale.to_s %>
    <% counterpart = resource.all_locales.find { |r| r.data.locale.to_s == locale.to_s } %>
    <a href="<%= counterpart ? counterpart.relative_url : locale_home_url(locale) %>"
       lang="<%= locale %>"
       hreflang="<%= locale %>"><%= t("locale.#{locale}") %></a>
  <% end %>
</nav>
```

`resource.all_locales` devolve **todas** as variantes, inclusive a atual — daí o
`next`. Quando a tradução não existe, `counterpart` é `nil` e o link cai na home
daquele idioma em vez de apontar para lugar nenhum.

- [ ] **Step 6: Criar o cabeçalho**

Crie `src/_partials/_header.erb`:

```erb
<header class="site-header">
  <a class="site-title" href="<%= locale_home_url(resource.data.locale) %>">
    <%= t("site.title") %>
  </a>

  <nav class="site-nav" aria-label="<%= t("nav.home") %>">
    <a href="<%= locale_home_url(resource.data.locale) %>"><%= t("nav.home") %></a>
    <a href="<%= relative_url("#{locale_prefix(resource.data.locale)}projects/") %>"><%= t("nav.projects") %></a>
    <a href="<%= relative_url("#{locale_prefix(resource.data.locale)}blog/") %>"><%= t("nav.blog") %></a>
  </nav>

  <%= render "locale_switcher", resource: resource %>
</header>
```

- [ ] **Step 7: Acrescentar o helper de prefixo usado pelo cabeçalho**

Em `plugins/builders/site_helpers.rb`, dentro de `build`, acrescente:

```ruby
    # "" para o idioma padrao, "pt/" para os demais
    helper :locale_prefix do |locale|
      if locale.to_s == site.config.default_locale.to_s
        ""
      else
        "#{locale}/"
      end
    end
```

- [ ] **Step 8: Substituir o rodapé**

Substitua o conteúdo de `src/_partials/_footer.erb` por:

```erb
<footer class="site-footer">
  <ul class="contact-links">
    <li><a href="<%= site.data.site_links.github %>" rel="me">GitHub</a></li>
    <li><a href="<%= site.data.site_links.linkedin %>" rel="me">LinkedIn</a></li>
    <li><a href="<%= site.data.site_links.email %>">E-mail</a></li>
  </ul>
  <p class="copyright">© <%= Time.now.year %> Vinicius Cole</p>
</footer>
```

- [ ] **Step 9: Ligar tudo no layout base**

Substitua `src/_layouts/default.erb` por:

```erb
<!doctype html>
<html lang="<%= resource.data.locale %>">
  <head>
    <%= render "head", metadata: site.metadata, title: data.title %>
  </head>
  <body class="<%= data.layout %> <%= data.page_class %>">
    <%= render "header", resource: resource %>

    <main>
      <%= yield %>
    </main>

    <%= render "footer" %>
  </body>
</html>
```

- [ ] **Step 10: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — cinco testes de layout verdes, além dos anteriores.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: layout base com navegacao traduzida e alternador de idioma"
```

---

### Task 4: Coleção de projetos e validação de front matter

Entrega: projetos viram conteúdo estruturado, com uma trava que reprova o build
quando um projeto está mal descrito ou falta num idioma.

**Files:**
- Modify: `config/initializers.rb`
- Create: `src/_projects/tic-tac-toe.en.md`
- Create: `src/_projects/tic-tac-toe.pt.md`
- Create: `src/_layouts/project.erb`
- Create: `test/projects_test.rb`

**Interfaces:**
- Consumes: `OutputHelpers`, `ROOT` (Task 1); layout `default` (Task 3)
- Produces: a coleção `projects`, acessível como
  `collections.projects.resources`. Produz o schema de front matter de projeto:
  obrigatórios `title`, `locale`, `slug`, `summary`, `tech`; opcionais `year`,
  `featured` (padrão `false`), `order` (padrão `999`), `repo`, `demo`
  (padrão `{"type" => "none"}`). Produz as páginas
  `/projects/tic-tac-toe/` e `/pt/projects/tic-tac-toe/`.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/projects_test.rb`:

```ruby
require "test_helper"

class ProjectsTest < Minitest::Test
  include OutputHelpers

  REQUIRED_FIELDS = %w[title locale slug summary tech].freeze

  def test_project_pages_are_generated_in_both_locales
    assert_page "projects/tic-tac-toe/index.html"
    assert_page "pt/projects/tic-tac-toe/index.html"
  end

  def test_each_locale_page_carries_its_own_content
    assert_includes page_body("projects/tic-tac-toe/index.html"), "Tic-Tac-Toe"
    assert_includes page_body("pt/projects/tic-tac-toe/index.html"), "Jogo da Velha"
  end

  def test_every_project_declares_the_required_fields
    project_files.each do |file|
      front_matter = read_front_matter(file)
      REQUIRED_FIELDS.each do |field|
        refute_nil front_matter[field],
          "#{file.basename}: falta o campo obrigatorio '#{field}'"
      end
    end
  end

  def test_every_project_exists_in_both_locales
    by_slug = project_files.group_by { |f| read_front_matter(f).fetch("slug") }

    by_slug.each do |slug, files|
      locales = files.map { |f| read_front_matter(f).fetch("locale") }.sort
      assert_equal %w[en pt], locales,
        "o projeto '#{slug}' precisa existir em en e pt, encontrei: #{locales.join(', ')}"
    end
  end

  private

  def project_files
    Dir.glob(ROOT.join("src/_projects/*.md")).map { |p| Pathname.new(p) }
  end

  # Le apenas o bloco YAML entre os delimitadores --- do topo do arquivo
  def read_front_matter(file)
    content = file.read
    match = content.match(/\A---\s*\n(.*?)\n---\s*\n/m)
    refute_nil match, "#{file.basename}: front matter ausente ou malformado"
    YAML.safe_load(match[1], permitted_classes: [Date])
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL — `esperava a pagina projects/tic-tac-toe/index.html`.

- [ ] **Step 3: Declarar a coleção**

Em `config/initializers.rb`, abaixo do bloco de locales, insira:

```ruby
  collections do
    projects do
      output true
      # ATENCAO: nao troque por uma string customizada de permalink.
      # Uma string custom ignora o prefixo de locale e faz en e pt gravarem
      # no mesmo arquivo, uma sobrescrevendo a outra em silencio.
      permalink "simple"
      sort_by "order"
    end
  end
```

- [ ] **Step 4: Criar o layout de projeto**

Crie `src/_layouts/project.erb`:

```erb
---
layout: default
---
<article class="project">
  <header class="project-header">
    <h1><%= data.title %></h1>
    <p class="project-summary"><%= data.summary %></p>

    <ul class="tech-list">
      <% Array(data.tech).each do |tech| %>
        <li><%= tech %></li>
      <% end %>
    </ul>

    <% if data.repo %>
      <a class="repo-link" href="<%= data.repo %>">
        <%= data.repo.sub("https://", "") %>
      </a>
    <% end %>
  </header>

  <div class="project-body">
    <%= yield %>
  </div>
</article>
```

- [ ] **Step 5: Criar o projeto tic-tac-toe em inglês**

Crie `src/_projects/tic-tac-toe.en.md`:

```markdown
---
layout: project
title: Tic-Tac-Toe in x86 Assembly
locale: en
slug: tic-tac-toe
year: 2019
featured: true
order: 1
summary: A tic-tac-toe game written in 16-bit x86 assembly for DOS, drawing its own board in VGA graphics mode.
tech: [x86 Assembly, NASM, DOS, VGA]
repo: https://github.com/viniciuscole/tic-tac-toe-assembly
demo:
  type: none
---

The whole game is written in NASM 16-bit real mode assembly, targeting DOS. It
switches the display into VGA mode 12h (640x480, 16 colours) through `int 10h`
and draws every line and circle itself: `draw.asm` implements Bresenham's line
and circle algorithms plus pixel plotting, and `vca.asm` holds the game logic,
the command parser and win detection.

Moves are typed as commands. `X11` plays X on row 1, column 1; `c` starts a new
game; `s` quits and restores the previous video mode.
```

- [ ] **Step 6: Criar o projeto tic-tac-toe em português**

Crie `src/_projects/tic-tac-toe.pt.md`:

```markdown
---
layout: project
title: Jogo da Velha em Assembly x86
locale: pt
slug: tic-tac-toe
year: 2019
featured: true
order: 1
summary: Um jogo da velha escrito em assembly x86 de 16 bits para DOS, que desenha o próprio tabuleiro em modo gráfico VGA.
tech: [Assembly x86, NASM, DOS, VGA]
repo: https://github.com/viniciuscole/tic-tac-toe-assembly
demo:
  type: none
---

O jogo inteiro é escrito em assembly NASM de 16 bits em modo real, para DOS. Ele
troca o vídeo para o modo VGA 12h (640x480, 16 cores) via `int 10h` e desenha
cada linha e círculo por conta própria: `draw.asm` implementa os algoritmos de
Bresenham para linha e círculo e o traçado de pixel, enquanto `vca.asm` concentra
a lógica do jogo, o interpretador de comandos e a detecção de vitória.

As jogadas são digitadas como comandos. `X11` joga X na linha 1, coluna 1; `c`
começa uma partida nova; `s` sai e restaura o modo de vídeo anterior.
```

- [ ] **Step 7: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — quatro testes de projeto verdes.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: colecao de projetos com validacao de front matter"
```

---

### Task 5: Dispatcher de demo

Entrega: o ponto de extensão que permite um projeto futuro embutir uma demo sem
tocar em nenhum arquivo existente.

**Files:**
- Create: `plugins/builders/demo_helper.rb`
- Create: `src/_partials/demos/_none.erb`
- Modify: `src/_layouts/project.erb`
- Create: `test/demo_dispatcher_test.rb`

**Interfaces:**
- Consumes: layout `project` e a coleção `projects` (Task 4)
- Produces: a constante `Builders::DemoHelper::DEMO_TYPES` (`%w[none jsdos]`) e o
  helper `demo_partial_for(resource) -> String`, que devolve o caminho de
  partial `"demos/<tipo>"`. A Fase 2 acrescenta `demos/_jsdos.erb` e nada mais.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/demo_dispatcher_test.rb`:

```ruby
require "test_helper"

class DemoDispatcherTest < Minitest::Test
  include OutputHelpers

  ALLOWED_TYPES = %w[none jsdos].freeze

  def test_project_without_demo_renders_the_placeholder
    body = page_body("projects/tic-tac-toe/index.html")
    assert_includes body, 'class="demo demo-none"'
  end

  def test_every_declared_demo_type_is_allowed
    Dir.glob(ROOT.join("src/_projects/*.md")).each do |path|
      file = Pathname.new(path)
      front_matter = YAML.safe_load(file.read.match(/\A---\s*\n(.*?)\n---\s*\n/m)[1])
      type = front_matter.dig("demo", "type") || "none"

      assert_includes ALLOWED_TYPES, type,
        "#{file.basename}: tipo de demo '#{type}' nao existe"
    end
  end

  def test_every_allowed_type_except_jsdos_has_a_partial
    # jsdos chega na Fase 2; os demais precisam existir agora
    (ALLOWED_TYPES - ["jsdos"]).each do |type|
      partial = ROOT.join("src/_partials/demos/_#{type}.erb")
      assert partial.file?, "falta o partial src/_partials/demos/_#{type}.erb"
    end
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL — a página do projeto não contém `class="demo demo-none"`.

- [ ] **Step 3: Criar o builder do dispatcher**

Crie `plugins/builders/demo_helper.rb`:

```ruby
class Builders::DemoHelper < SiteBuilder
  # Tipos de demo suportados. Acrescentar um tipo aqui e criar o partial
  # correspondente em src/_partials/demos/_<tipo>.erb e tudo que e preciso
  # para um projeto novo embutir uma demo.
  DEMO_TYPES = %w[none jsdos].freeze

  def build
    helper :demo_partial_for do |resource|
      type = resource.data.dig(:demo, :type) || "none"

      if DEMO_TYPES.include?(type)
        "demos/#{type}"
      else
        Bridgetown.logger.warn "Demo",
          "tipo desconhecido #{type.inspect} em #{resource.relative_path}, usando 'none'"
        "demos/none"
      end
    end
  end
end
```

Um tipo inválido no front matter degrada para o placeholder e registra aviso no
build — o site não quebra por causa de um erro de digitação, mas o erro aparece.
A Task 4 já reprova esse caso no `rake check`; o aviso é a rede de segurança de
quem estiver rodando `bin/bridgetown start` localmente.

- [ ] **Step 4: Criar o partial de projeto sem demo**

Crie `src/_partials/demos/_none.erb`:

```erb
<div class="demo demo-none" hidden aria-hidden="true"></div>
```

O elemento fica escondido: um projeto sem demo não mostra caixa vazia. Ele
existe no HTML para o dispatcher ser verificável por teste.

- [ ] **Step 5: Chamar o dispatcher no layout de projeto**

Em `src/_layouts/project.erb`, logo antes de `<div class="project-body">`,
insira:

```erb
  <%= render demo_partial_for(resource) %>
```

- [ ] **Step 6: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — três testes de dispatcher verdes.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: dispatcher de demo como ponto de extensao para projetos"
```

---

### Task 6: Home e listagem de projetos

Entrega: as duas páginas que dão sentido ao site — a apresentação e a galeria.

**Files:**
- Create: `src/_partials/_project_card.erb`
- Create: `src/projects.en.md`
- Create: `src/projects.pt.md`
- Modify: `src/index.en.md`
- Modify: `src/index.pt.md`
- Modify: `src/_locales/en.yml`
- Modify: `src/_locales/pt.yml`
- Create: `test/home_test.rb`

**Interfaces:**
- Consumes: a coleção `projects` e o layout `project` (Task 4); o layout `page`
  do scaffold; `OutputHelpers` (Task 1). As URLs `/projects/` e `/pt/projects/`
  precisam bater com os links do cabeçalho (Task 3).
- Produces: o partial `_project_card.erb`, que espera o local `project:` (um
  recurso da coleção). Produz as chaves `home.intro`, `home.featured`,
  `home.latest_posts`, `home.contact`, `projects.title`, `projects.intro`.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/home_test.rb`:

```ruby
require "test_helper"

class HomeTest < Minitest::Test
  include OutputHelpers

  def test_projects_index_exists_in_both_locales
    assert_page "projects/index.html"
    assert_page "pt/projects/index.html"
  end

  def test_projects_index_lists_the_project_of_its_own_locale
    assert_includes page_body("projects/index.html"), "Tic-Tac-Toe in x86 Assembly"
    assert_includes page_body("pt/projects/index.html"), "Jogo da Velha em Assembly x86"
  end

  def test_projects_index_does_not_leak_the_other_locale
    refute_includes page_body("projects/index.html"), "Jogo da Velha"
    refute_includes page_body("pt/projects/index.html"), "Tic-Tac-Toe in x86"
  end

  def test_home_features_the_flagged_project
    assert_includes page_body("index.html"), "Tic-Tac-Toe in x86 Assembly"
  end

  def test_project_card_links_to_the_project_page
    assert_includes page_body("projects/index.html"), 'href="/projects/tic-tac-toe/"'
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL — `esperava a pagina projects/index.html`.

- [ ] **Step 3: Acrescentar as chaves de tradução**

Em `src/_locales/en.yml`, acrescente sob `en:`:

```yaml
  home:
    intro: "I build software. Some of it runs right here on this page."
    featured: "Featured projects"
    latest_posts: "Latest posts"
    contact: "Get in touch"
  projects:
    title: "Projects"
    intro: "Things I have built, and things I am still building."
```

Em `src/_locales/pt.yml`, acrescente sob `pt:`:

```yaml
  home:
    intro: "Eu construo software. Parte dele roda aqui mesmo nesta página."
    featured: "Projetos em destaque"
    latest_posts: "Últimos posts"
    contact: "Fale comigo"
  projects:
    title: "Projetos"
    intro: "Coisas que eu construí, e coisas que ainda estou construindo."
```

- [ ] **Step 4: Criar o card de projeto**

Crie `src/_partials/_project_card.erb`:

```erb
<article class="project-card">
  <h3>
    <a href="<%= project.relative_url %>"><%= project.data.title %></a>
  </h3>

  <p class="project-card-summary"><%= project.data.summary %></p>

  <ul class="tech-list">
    <% Array(project.data.tech).each do |tech| %>
      <li><%= tech %></li>
    <% end %>
  </ul>

  <% if project.data.year %>
    <p class="project-card-year"><%= project.data.year %></p>
  <% end %>
</article>
```

- [ ] **Step 5: Criar a listagem de projetos em inglês**

Crie `src/projects.en.md`:

```markdown
---
layout: page
title: Projects
locale: en
permalink: /projects/
---

<h1><%= t("projects.title") %></h1>
<p class="page-intro"><%= t("projects.intro") %></p>

<div class="project-grid">
  <% collections.projects.resources
       .select { |p| p.data.locale.to_s == resource.data.locale.to_s }
       .sort_by { |p| p.data.order || 999 }
       .each do |project| %>
    <%= render "project_card", project: project %>
  <% end %>
</div>
```

- [ ] **Step 6: Criar a listagem de projetos em português**

Crie `src/projects.pt.md`:

```markdown
---
layout: page
title: Projetos
locale: pt
permalink: /pt/projects/
---

<h1><%= t("projects.title") %></h1>
<p class="page-intro"><%= t("projects.intro") %></p>

<div class="project-grid">
  <% collections.projects.resources
       .select { |p| p.data.locale.to_s == resource.data.locale.to_s }
       .sort_by { |p| p.data.order || 999 }
       .each do |project| %>
    <%= render "project_card", project: project %>
  <% end %>
</div>
```

O filtro por locale é obrigatório: `collections.projects.resources` devolve os
recursos de **todos** os idiomas. Sem ele, a listagem em inglês mostraria também
os projetos em português.

- [ ] **Step 7: Escrever a home de verdade**

Substitua `src/index.en.md` inteiro por:

```markdown
---
layout: page
title: Vinicius Cole
locale: en
permalink: /
---

<section class="hero">
  <h1><%= t("site.title") %></h1>
  <p class="tagline"><%= t("site.tagline") %></p>
  <p class="intro"><%= t("home.intro") %></p>
</section>

<section class="featured">
  <h2><%= t("home.featured") %></h2>

  <div class="project-grid">
    <% collections.projects.resources
         .select { |p| p.data.locale.to_s == resource.data.locale.to_s && p.data.featured }
         .sort_by { |p| p.data.order || 999 }
         .each do |project| %>
      <%= render "project_card", project: project %>
    <% end %>
  </div>
</section>
```

Substitua `src/index.pt.md` inteiro por:

```markdown
---
layout: page
title: Vinicius Cole
locale: pt
permalink: /pt/
---

<section class="hero">
  <h1><%= t("site.title") %></h1>
  <p class="tagline"><%= t("site.tagline") %></p>
  <p class="intro"><%= t("home.intro") %></p>
</section>

<section class="featured">
  <h2><%= t("home.featured") %></h2>

  <div class="project-grid">
    <% collections.projects.resources
         .select { |p| p.data.locale.to_s == resource.data.locale.to_s && p.data.featured }
         .sort_by { |p| p.data.order || 999 }
         .each do |project| %>
      <%= render "project_card", project: project %>
    <% end %>
  </div>
</section>
```

Os corpos são idênticos de propósito: todo o texto visível vem de `t()`, então
não há nada para traduzir dentro do template. O que muda é só o front matter.

- [ ] **Step 8: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — cinco testes de home e listagem verdes.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: home com projetos em destaque e listagem de projetos"
```

---

### Task 7: Blog

Entrega: posts em Markdown, listados por idioma, com o caso real de um post que
existe em um idioma só.

**Files:**
- Delete: `src/_posts/2026-08-16-welcome-to-bridgetown.md`
- Create: `src/_posts/2026-08-16-porting-dos-assembly-to-the-browser.en.md`
- Create: `src/blog.en.md`
- Create: `src/blog.pt.md`
- Delete: `src/posts.md`
- Modify: `src/_layouts/post.erb`
- Modify: `src/_locales/en.yml`, `src/_locales/pt.yml`
- Create: `test/blog_test.rb`

**Interfaces:**
- Consumes: o layout `default` (Task 3) e o layout `page` do scaffold;
  `OutputHelpers` (Task 1). As URLs `/blog/` e `/pt/blog/` precisam bater com os
  links do cabeçalho (Task 3).
- Produces: as chaves `blog.title`, `blog.intro`, `blog.empty`. Produz as páginas
  `/blog/` e `/pt/blog/`.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/blog_test.rb`:

```ruby
require "test_helper"

class BlogTest < Minitest::Test
  include OutputHelpers

  def test_blog_index_exists_in_both_locales
    assert_page "blog/index.html"
    assert_page "pt/blog/index.html"
  end

  def test_english_blog_lists_the_english_post
    assert_includes page_body("blog/index.html"),
      "Porting DOS assembly to the browser"
  end

  def test_portuguese_blog_shows_the_empty_state
    # o post so existe em ingles, entao a listagem em portugues fica vazia
    body = page_body("pt/blog/index.html")
    refute_includes body, "Porting DOS assembly to the browser"
    assert_includes body, "Nenhum post por aqui ainda"
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL — `esperava a pagina blog/index.html`.

- [ ] **Step 3: Acrescentar as chaves de tradução**

Em `en.yml`, sob `en:`:

```yaml
  blog:
    title: "Blog"
    intro: "Notes on things I build."
    empty: "Nothing here yet"
```

Em `pt.yml`, sob `pt:`:

```yaml
  blog:
    title: "Blog"
    intro: "Notas sobre as coisas que eu construo."
    empty: "Nenhum post por aqui ainda"
```

- [ ] **Step 4: Trocar o post de exemplo por um real**

Apague `src/_posts/2026-08-16-welcome-to-bridgetown.md` e `src/posts.md`.

Crie `src/_posts/2026-08-16-porting-dos-assembly-to-the-browser.en.md`:

```markdown
---
layout: post
title: Porting DOS assembly to the browser
locale: en
date: 2026-08-16
---

My tic-tac-toe game is written in 16-bit x86 real mode assembly. There is no
compiler that turns that into WebAssembly — the instruction set, the segmented
memory model and the DOS interrupts have no equivalent target.

So the plan is emulation: assemble the original source with NASM, link it into a
DOS executable, and run that executable inside DOSBox compiled to WebAssembly.
The WebAssembly here is the emulator, not my code, and I think that honesty
matters more than the label.

The build already works: `nasm -f obj` assembles both source files without a
single change, and Open Watcom's linker produces a 3,244 byte DOS executable.
```

- [ ] **Step 5: Ajustar o layout de post**

Substitua `src/_layouts/post.erb` por:

```erb
---
layout: default
---
<article class="post">
  <header>
    <h1><%= data.title %></h1>
    <time datetime="<%= data.date.strftime("%Y-%m-%d") %>">
      <%= data.date.strftime("%Y-%m-%d") %>
    </time>
  </header>

  <div class="post-body">
    <%= yield %>
  </div>
</article>
```

- [ ] **Step 6: Criar as listagens do blog**

Crie `src/blog.en.md`:

```markdown
---
layout: page
title: Blog
locale: en
permalink: /blog/
---

<h1><%= t("blog.title") %></h1>
<p class="page-intro"><%= t("blog.intro") %></p>

<% posts = collections.posts.resources
     .select { |p| p.data.locale.to_s == resource.data.locale.to_s }
     .sort_by { |p| p.data.date }.reverse %>

<% if posts.empty? %>
  <p class="empty-state"><%= t("blog.empty") %></p>
<% else %>
  <ul class="post-list">
    <% posts.each do |post| %>
      <li>
        <a href="<%= post.relative_url %>"><%= post.data.title %></a>
        <time datetime="<%= post.data.date.strftime("%Y-%m-%d") %>">
          <%= post.data.date.strftime("%Y-%m-%d") %>
        </time>
      </li>
    <% end %>
  </ul>
<% end %>
```

Crie `src/blog.pt.md`:

```markdown
---
layout: page
title: Blog
locale: pt
permalink: /pt/blog/
---

<h1><%= t("blog.title") %></h1>
<p class="page-intro"><%= t("blog.intro") %></p>

<% posts = collections.posts.resources
     .select { |p| p.data.locale.to_s == resource.data.locale.to_s }
     .sort_by { |p| p.data.date }.reverse %>

<% if posts.empty? %>
  <p class="empty-state"><%= t("blog.empty") %></p>
<% else %>
  <ul class="post-list">
    <% posts.each do |post| %>
      <li>
        <a href="<%= post.relative_url %>"><%= post.data.title %></a>
        <time datetime="<%= post.data.date.strftime("%Y-%m-%d") %>">
          <%= post.data.date.strftime("%Y-%m-%d") %>
        </time>
      </li>
    <% end %>
  </ul>
<% end %>
```

- [ ] **Step 7: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — três testes de blog verdes. O teste do estado vazio prova que
um post em um idioma só não vaza para o outro.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: blog bilingue com estado vazio por idioma"
```

---

### Task 8: Design visual

Entrega: a identidade do site — base moderna e limpa com acentos retrô, tema
claro/escuro, e nenhuma requisição externa.

**Files:**
- Create: `frontend/styles/tokens.css`
- Create: `frontend/styles/base.css`
- Create: `frontend/styles/components.css`
- Modify: `frontend/styles/index.css`
- Modify: `frontend/javascript/index.js`
- Modify: `src/_partials/_head.erb`
- Create: `test/assets_test.rb`

**Interfaces:**
- Consumes: as classes CSS emitidas pelos partials das tarefas 3 a 7
  (`site-header`, `site-nav`, `locale-switcher`, `site-footer`, `contact-links`,
  `hero`, `tagline`, `project-grid`, `project-card`, `tech-list`, `post-list`,
  `empty-state`, `demo`)
- Produces: os tokens CSS `--bg`, `--fg`, `--muted`, `--accent`, `--border`,
  `--font-mono`, `--font-body`; o atributo `data-theme` em `<html>`, com os
  valores `light` e `dark`.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/assets_test.rb`:

```ruby
require "test_helper"

class AssetsTest < Minitest::Test
  include OutputHelpers

  def test_no_external_requests_in_the_published_html
    Dir.glob(OUTPUT.join("**/*.html")).each do |path|
      body = File.read(path)
      offenders = body.scan(/(?:src|href)="(https?:\/\/[^"]+)"/).flatten
        .reject { |url| allowed_external?(url) }

      assert_empty offenders,
        "#{path}: recurso externo carregado pela pagina: #{offenders.join(', ')}"
    end
  end

  def test_theme_tokens_are_defined
    css = ROOT.join("frontend/styles/tokens.css").read
    %w[--bg --fg --muted --accent --border --font-mono --font-body].each do |token|
      assert_includes css, token, "token #{token} nao definido"
    end
  end

  private

  # Links de navegacao para fora sao permitidos; o que nao pode e a pagina
  # *carregar* recurso de terceiro (script, folha de estilo, fonte, imagem).
  def allowed_external?(url)
    !url.match?(/\.(js|css|woff2?|ttf|png|jpe?g|svg|gif)(\?|$)/)
  end
end
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bundle exec rake check`
Expected: FAIL — `token --bg nao definido`, pois `tokens.css` ainda não existe.

- [ ] **Step 3: Criar os tokens**

Crie `frontend/styles/tokens.css`:

```css
:root {
  /* acentos derivados da paleta VGA de 16 cores, o elo com o projeto em assembly */
  --vga-green: #00aa00;
  --vga-cyan: #00aaaa;
  --vga-amber: #aa5500;

  --font-body: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
    "Helvetica Neue", Arial, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace;

  --space: 1rem;
  --measure: 68ch;
  --radius: 4px;
}

:root,
:root[data-theme="light"] {
  --bg: #fbfbf9;
  --fg: #16161a;
  --muted: #5c5c66;
  --accent: var(--vga-green);
  --border: #e0e0d8;
}

:root[data-theme="dark"] {
  --bg: #0f1115;
  --fg: #e8e8e3;
  --muted: #9a9aa4;
  --accent: #33cc33;
  --border: #262a33;
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #0f1115;
    --fg: #e8e8e3;
    --muted: #9a9aa4;
    --accent: #33cc33;
    --border: #262a33;
  }
}
```

- [ ] **Step 4: Criar a base**

Crie `frontend/styles/base.css`:

```css
*, *::before, *::after { box-sizing: border-box; }

body {
  margin: 0;
  background: var(--bg);
  color: var(--fg);
  font-family: var(--font-body);
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
}

main {
  max-width: var(--measure);
  margin: 0 auto;
  padding: calc(var(--space) * 3) var(--space);
}

h1, h2, h3 {
  font-family: var(--font-mono);
  font-weight: 600;
  letter-spacing: -0.01em;
  line-height: 1.25;
}

a { color: var(--accent); }

a:focus-visible,
button:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}

code, pre { font-family: var(--font-mono); }
```

- [ ] **Step 5: Criar os componentes**

Crie `frontend/styles/components.css`:

```css
.site-header {
  display: flex;
  align-items: center;
  gap: var(--space);
  flex-wrap: wrap;
  max-width: var(--measure);
  margin: 0 auto;
  padding: var(--space);
  border-bottom: 1px solid var(--border);
}

.site-title {
  font-family: var(--font-mono);
  font-weight: 700;
  text-decoration: none;
  color: var(--fg);
}

.site-nav { display: flex; gap: var(--space); margin-left: auto; }
.locale-switcher { display: flex; gap: 0.5rem; font-family: var(--font-mono); font-size: 0.875rem; }

.hero .tagline { color: var(--muted); font-family: var(--font-mono); margin-top: 0; }

.project-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: calc(var(--space) * 1.5);
}

.project-card {
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: var(--space);
}

.project-card h3 { margin-top: 0; }
.project-card-summary { color: var(--muted); }
.project-card-year { color: var(--muted); font-family: var(--font-mono); font-size: 0.8125rem; }

.tech-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  list-style: none;
  padding: 0;
  font-family: var(--font-mono);
  font-size: 0.8125rem;
}

.tech-list li {
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 0.125rem 0.5rem;
  color: var(--muted);
}

.post-list { list-style: none; padding: 0; }
.post-list li { display: flex; justify-content: space-between; gap: var(--space); padding: 0.5rem 0; border-bottom: 1px solid var(--border); }
.post-list time, .post time { color: var(--muted); font-family: var(--font-mono); font-size: 0.875rem; }

.empty-state { color: var(--muted); font-style: italic; }

.site-footer {
  max-width: var(--measure);
  margin: calc(var(--space) * 4) auto 0;
  padding: var(--space);
  border-top: 1px solid var(--border);
}

.contact-links { display: flex; gap: var(--space); list-style: none; padding: 0; font-family: var(--font-mono); }
.copyright { color: var(--muted); font-size: 0.875rem; }

.theme-toggle {
  background: none;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--fg);
  cursor: pointer;
  font-family: var(--font-mono);
  font-size: 0.875rem;
  padding: 0.125rem 0.5rem;
}
```

- [ ] **Step 6: Importar tudo no index.css**

No topo de `frontend/styles/index.css`, acrescente:

```css
@import "./tokens.css";
@import "./base.css";
@import "./components.css";
```

O esbuild resolve `@import` de CSS nativamente ao empacotar, então não é preciso
mexer no `postcss.config.js`.

- [ ] **Step 7: Implementar o alternador de tema**

Substitua o conteúdo de `frontend/javascript/index.js` por:

```javascript
import "../styles/index.css"

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
```

Confira se `import "../styles/index.css"` já existia no arquivo gerado; se sim,
não duplique a linha.

- [ ] **Step 8: Acrescentar o botão de tema ao cabeçalho**

Em `src/_partials/_header.erb`, logo após o `render "locale_switcher"`:

```erb
  <button class="theme-toggle" type="button" aria-label="<%= t("nav.theme") %>">
    ◐
  </button>
```

Acrescente `theme: "Toggle theme"` sob `nav:` em `en.yml` e
`theme: "Alternar tema"` sob `nav:` em `pt.yml`.

- [ ] **Step 9: Rodar e confirmar que passa**

Run: `bundle exec rake check`
Expected: PASS — dois testes de assets verdes, e nenhum recurso externo no HTML.

- [ ] **Step 10: Verificar no navegador**

Run: `bin/bridgetown start`
Abra `http://localhost:4000`, confira o layout, clique no alternador de tema e no
de idioma. Encerre com Ctrl+C.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: identidade visual com tokens, tema claro/escuro e acentos VGA"
```

---

### Task 9: Verificação de links com html-proofer

Entrega: nenhum link interno quebrado e nenhuma imagem sem texto alternativo
chegam à produção.

**Files:**
- Modify: `Gemfile`
- Modify: `Rakefile`

**Interfaces:**
- Consumes: a tarefa `check` (Task 1) e o diretório `output/`
- Produces: a tarefa `rake proof`, incorporada a `rake check`

- [ ] **Step 1: Acrescentar a gem**

No `Gemfile`, dentro do grupo `:test`:

```ruby
  gem "html-proofer", "~> 5.0"
```

Run: `bundle install`

- [ ] **Step 2: Acrescentar a tarefa ao Rakefile**

```ruby
desc "Verifica links internos e imagens no HTML gerado"
task :proof do
  require "html_proofer"

  HTMLProofer.check_directory(
    "output",
    disable_external: true,          # links externos nao devem quebrar o build
    check_img_http: true,
    enforce_https: false,
    allow_missing_href: false,
    ignore_missing_alt: false
  ).run
end
```

Altere a tarefa `check` para incluí-la:

```ruby
task :check do
  sh "bin/bridgetown build"
  Rake::Task["minitest"].invoke
  Rake::Task["proof"].invoke
end
```

`disable_external: true` é deliberado: links para GitHub ou LinkedIn saindo do ar
temporariamente não podem reprovar um deploy nosso.

- [ ] **Step 3: Rodar e corrigir o que aparecer**

Run: `bundle exec rake check`
Expected: pode FALHAR na primeira vez, apontando links internos ou imagens sem
`alt`. Corrija cada apontamento e rode de novo até passar. Não relaxe as opções
do html-proofer para fazer o teste passar.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: verificacao de links e imagens com html-proofer"
```

---

### Task 10: CI e deploy no Cloudflare Pages

Entrega: todo push na `main` publica o site; todo pull request roda a suíte.

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `README.md` (substituir o gerado)

**Interfaces:**
- Consumes: `rake check` (tarefas 1 e 9)
- Produces: o workflow `ci`, e a dependência dos segredos
  `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`

- [ ] **Step 1: Criar o projeto no Cloudflare Pages**

No painel do Cloudflare: **Workers & Pages → Create → Pages → Direct Upload**,
com o nome `viniciuscole-dev`. Direct Upload é o modo certo aqui: quem constrói
somos nós, o Pages só recebe o resultado pronto.

Gere um API token em **My Profile → API Tokens** com a permissão
`Cloudflare Pages: Edit`. Guarde o token e o Account ID.

- [ ] **Step 2: Registrar os segredos no GitHub**

No repositório: **Settings → Secrets and variables → Actions → New repository
secret**. Crie `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`.

- [ ] **Step 3: Criar o workflow**

Crie `.github/workflows/ci.yml`:

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: npm

      - name: Instalar dependencias de frontend
        run: npm ci

      - name: Construir o frontend
        run: npm run esbuild

      - name: Construir o site e rodar a suite
        run: bundle exec rake check
        env:
          BRIDGETOWN_ENV: production

      - name: Publicar no Cloudflare Pages
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy output --project-name=viniciuscole-dev
```

`ruby/setup-ruby` com `bundler-cache: true` lê o `.ruby-version` do repositório,
então o CI usa exatamente a mesma versão de Ruby da sua máquina.

- [ ] **Step 4: Escrever o README**

Substitua `README.md`:

```markdown
# viniciuscole.dev

Site pessoal, gerado com [Bridgetown](https://www.bridgetownrb.com) e publicado
no Cloudflare Pages.

## Rodar localmente

    bundle install
    npm install
    bin/bridgetown start

## Verificar antes de publicar

    bundle exec rake check

Constrói o site, roda a suíte de testes e verifica links e imagens.

## Adicionar um projeto

Crie `src/_projects/<slug>.en.md` e `src/_projects/<slug>.pt.md`. Os dois
idiomas são obrigatórios — a suíte reprova um projeto que exista em apenas um.

Campos obrigatórios: `title`, `locale`, `slug`, `summary`, `tech`.
Opcionais: `year`, `featured`, `order`, `repo`, `demo`.

Para embutir uma demo, use `demo.type` com um dos tipos registrados em
`plugins/builders/demo_helper.rb` e crie o partial correspondente em
`src/_partials/demos/`.

## Configuração

Tudo vive em `config/initializers.rb`. Não crie `bridgetown.config.yml`: o
Bridgetown 2 não o utiliza.

O permalink da coleção `projects` **precisa** ser `"simple"`. Um permalink
customizado ignora o prefixo de idioma e faz as duas traduções gravarem no mesmo
arquivo, uma sobrescrevendo a outra sem aviso.
```

- [ ] **Step 5: Commit e verificar o CI**

```bash
git add -A
git commit -m "feat: CI no GitHub Actions com deploy no Cloudflare Pages"
git push
```

Acompanhe a execução em **Actions**. Expected: build verde e o site acessível na
URL `*.pages.dev` do projeto.

---

### Task 11: Domínio e DNS

Entrega: `viniciuscole.dev` respondendo com HTTPS válido.

**Files:** nenhum — esta tarefa é executada nos painéis do Cloudflare.

**Interfaces:**
- Consumes: o projeto Pages `viniciuscole-dev` publicado (Task 10)
- Produces: o domínio de produção

- [ ] **Step 1: Registrar o domínio**

No Cloudflare: **Domain Registration → Register Domain**, busque
`viniciuscole.dev`. Em 2026-08-16 as consultas de DNS indicavam o domínio livre;
confirme no momento da compra. Custo aproximado: US$ 12/ano.

Registrando pelo Cloudflare, a zona de DNS já nasce na mesma conta do Pages.

- [ ] **Step 2: Ligar o domínio ao projeto Pages**

No projeto Pages: **Custom domains → Set up a custom domain**, informe
`viniciuscole.dev`. Repita para `www.viniciuscole.dev` se quiser o redirecionamento.

O Cloudflare cria os registros de DNS e emite o certificado sozinho.

- [ ] **Step 3: Verificar**

```bash
curl -sI https://viniciuscole.dev | head -3
```

Expected: `HTTP/2 200`. Se o certificado ainda estiver sendo emitido, aguarde
alguns minutos e repita.

Lembre que `.dev` é um TLD com HSTS preload: **não existe acesso por HTTP**.
Testar com `http://` vai falhar por definição, e isso é o comportamento correto.

- [ ] **Step 4: Registrar a URL no site**

Em `config/initializers.rb`, preencha:

```ruby
  url "https://viniciuscole.dev"
```

```bash
git add -A
git commit -m "chore: registrar a URL de producao"
git push
```

---

## Critérios de conclusão da Fase 1

- `viniciuscole.dev` responde com HTTPS válido
- Home, listagem de projetos, página do tic-tac-toe e blog funcionam em inglês e
  português, com o alternador correto em todas
- `bundle exec rake check` verde
- Um projeto novo exige apenas dois arquivos Markdown
