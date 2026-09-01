require "test_helper"

# Builders::TagPages.label_for e .tags_of sao testados diretamente (sem passar
# por um build completo), entao o plugin precisa ser carregado neste processo.
# Mesmo preambulo de demo_dispatcher_test.rb: `class Builders::TagPages` (forma
# compacta) exige que o modulo `Builders` ja exista, e quem o cria em producao
# e o autoload do Zeitwerk, que so roda quando um Bridgetown::Site sobe.
require "bridgetown"
require ROOT.join("plugins/site_builder")
module Builders; end unless defined?(Builders)
require ROOT.join("plugins/builders/tag_pages")

class TagsTest < Minitest::Test
  include OutputHelpers

  # Num processo sem Bridgetown::Site no ar, o I18n nao conhece os locales do
  # projeto: quem os registra e Site#locale, no boot. Sem isto, chamar
  # label_for com :pt levanta I18n::InvalidLocale -- e o teste passaria ou nao
  # conforme a ordem aleatoria em que outra suite tenha subido um Site antes.
  # Configurar aqui torna a suite independente de ordem.
  def setup
    I18n.load_path |= Dir[ROOT.join("src/_locales/*.yml").to_s]
    I18n.available_locales = %i[en pt]
  end

  # As tags do post inaugural. Vem do front matter, nao de uma lista fixa aqui:
  # duplicar deixaria o teste verde depois de alguem trocar as tags do post.
  def post_tags
    @post_tags ||= begin
      front_matter = YAML.safe_load(
        ROOT.join("src/_posts/2026-08-16-porting-dos-assembly-to-the-browser.en.md")
          .read.split("---")[1],
        permitted_classes: [Date]
      )
      front_matter.fetch("tags")
    end
  end

  def test_the_post_carries_multiple_tags
    # Multiplas tags por post e requisito explicito, entao tem teste explicito:
    # o resto desta suite so prova o que prova porque ha mais de uma.
    assert_operator post_tags.length, :>=, 2,
      "o post precisa de pelo menos duas tags para esta suite significar algo"
  end

  def test_tag_index_exists_in_both_locales
    assert_page "tags/index.html"
    assert_page "pt/tags/index.html"
  end

  def test_tag_index_links_every_tag_in_use
    en = page_body("tags/index.html")
    pt = page_body("pt/tags/index.html")

    post_tags.each do |tag|
      assert_includes en, %(href="/tags/#{tag}/"),
        "o indice em ingles nao lista a tag #{tag}"
      assert_includes pt, %(href="/pt/tags/#{tag}/"),
        "o indice em portugues nao lista a tag #{tag}"
    end
  end

  def test_every_tag_gets_a_page_in_both_locales
    post_tags.each do |tag|
      assert_page "tags/#{tag}/index.html"
      assert_page "pt/tags/#{tag}/index.html"
    end
  end

  # Um post com N tags aparece na pagina de todas as N.
  def test_a_post_appears_on_the_page_of_each_of_its_tags
    post_tags.each do |tag|
      assert_includes page_body("tags/#{tag}/index.html"),
        "Porting DOS assembly to the browser"
      assert_includes page_body("pt/tags/#{tag}/index.html"),
        "Portando assembly de DOS para o navegador"
    end
  end

  def test_a_post_page_lists_all_of_its_tags
    en = page_body("2026/08/16/porting-dos-assembly-to-the-browser/index.html")
    pt = page_body("pt/2026/08/16/porting-dos-assembly-to-the-browser/index.html")

    post_tags.each do |tag|
      assert_includes en, %(href="/tags/#{tag}/")
      assert_includes pt, %(href="/pt/tags/#{tag}/")
    end
  end

  # A guarda central da feature. As paginas de tag sao GeneratedPage, e o
  # pareamento de traducoes so acontece porque damos a chave canonica da tag
  # como `slug` e montamos os caminhos de forma que o `localeless_path` das
  # duas coincida (ver Bridgetown::Localizable). Se qualquer um dos dois mudar,
  # o alternador volta a cair para a home do outro idioma -- em silencio, com
  # o build passando.
  def test_locale_switcher_pairs_the_two_versions_of_a_tag_page
    tag = post_tags.first

    assert_includes page_body("tags/#{tag}/index.html"),
      %(href="/pt/tags/#{tag}/")
    assert_includes page_body("pt/tags/#{tag}/index.html"),
      %(href="/tags/#{tag}/")
  end

  # Paginas geradas nao passam pelo render_with_locale do Bridgetown; sem o
  # hook :generated_pages, :pre_render em tag_pages.rb elas renderizariam com
  # o locale padrao e a pagina em portugues sairia inteira em ingles.
  # `emulation` e a tag escolhida porque o rotulo dela realmente difere entre
  # os idiomas -- com "Assembly" ou "WebAssembly", identicos nos dois, este
  # teste passaria mesmo com o bug presente.
  def test_portuguese_tag_page_renders_in_portuguese
    body = page_body("pt/tags/emulation/index.html")

    assert_includes body, '<html lang="pt">'
    assert_includes body, "Emulação"
    assert_includes body, 'aria-label="Idioma"'
    refute_includes body, "<h1>Emulation</h1>"
  end

  def test_english_tag_page_renders_in_english
    body = page_body("tags/emulation/index.html")

    assert_includes body, '<html lang="en">'
    assert_includes body, "<h1>Emulation</h1>"
    refute_includes body, "Emulação"
  end

  # O locales_test ja cobra conjuntos de chave identicos entre en.yml e pt.yml,
  # mas paridade nao pega este caso: uma tag ausente nos *dois* arquivos e
  # simetrica e passaria por la. Este teste cobra cobertura, nao simetria.
  def test_every_tag_in_use_has_a_label_in_both_locales
    tables = {
      "en" => YAML.load_file(ROOT.join("src/_locales/en.yml")).fetch("en"),
      "pt" => YAML.load_file(ROOT.join("src/_locales/pt.yml")).fetch("pt"),
    }

    tables.each do |locale, table|
      labels = table.fetch("tags", {}).fetch("label", {})
      post_tags.each do |tag|
        assert labels.key?(tag),
          "tag #{tag.inspect} em uso mas sem rotulo em #{locale}.yml"
      end
    end
  end

  # Front matter malformado nunca derruba o build. Testado direto no metodo do
  # plugin porque provar isso pelo build exigiria publicar um post com uma tag
  # sem rotulo -- exatamente o que o teste acima proibe.
  def test_a_tag_without_a_label_degrades_to_the_raw_key
    assert_equal "tag-que-nao-existe",
      Builders::TagPages.label_for("tag-que-nao-existe", :pt)
  end

  def test_tags_of_tolerates_missing_malformed_and_single_values
    resource = Struct.new(:data)

    assert_equal [], Builders::TagPages.tags_of(resource.new({}))
    assert_equal [], Builders::TagPages.tags_of(resource.new({ tags: nil }))
    assert_equal ["solo"], Builders::TagPages.tags_of(resource.new({ tags: "solo" }))
    assert_equal %w[a b], Builders::TagPages.tags_of(resource.new({ tags: ["a", " b "] }))
  end
end
