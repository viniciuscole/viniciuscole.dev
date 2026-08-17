require "test_helper"

# Tudo que o <head> publica: titulo, descricao, Open Graph, canonical e
# hreflang. E o que buscador indexa e o que Slack/WhatsApp/LinkedIn mostram
# no preview — nada disso aparece na tela, entao so um teste pega quando
# quebra.
class HeadTest < Minitest::Test
  include OutputHelpers

  # O scaffold do Bridgetown deixa `title: Your awesome title`,
  # `email: your-email@example.com` e uma description comecando com "Write an
  # awesome description...". Esses valores ja foram publicados uma vez em
  # *todas* as paginas do site, no <title> e na meta description, sem que
  # nenhum teste piscasse. Nao pode acontecer de novo.
  PLACEHOLDER = /awesome|example\.com|lorem ipsum/i

  def test_no_scaffold_placeholder_text_in_the_published_html
    html_pages.each do |path|
      found = File.read(path)[PLACEHOLDER]
      assert_nil found,
        "#{path}: texto de placeholder do scaffold no HTML publicado (#{found.inspect})"
    end
  end

  def test_every_page_has_a_real_title_and_description
    html_pages.each do |path|
      body = File.read(path)
      title = body[%r{<title>(.*?)</title>}m, 1].to_s.strip
      description = body[/<meta name="description" content="([^"]*)"/, 1].to_s.strip

      refute_empty title, "#{path}: <title> vazio"
      assert_includes title, "Vinicius Cole",
        "#{path}: <title> nao concorda com site.title: #{title.inspect}"
      refute_empty description, "#{path}: meta description vazia"
    end
  end

  def test_every_page_carries_the_open_graph_tags
    html_pages.each do |path|
      body = File.read(path)
      %w[og:title og:description og:type og:url og:locale].each do |property|
        assert_match(/<meta property="#{property}" content="[^"]+" \/>/, body,
          "#{path}: falta a meta tag #{property}")
      end
      assert_match(%r{<link rel="canonical" href="[^"]+" />}, body,
        "#{path}: falta o link canonical")
    end
  end

  def test_open_graph_description_of_a_project_is_the_project_summary
    body = page_body("projects/tic-tac-toe/index.html")

    assert_includes body,
      '<meta property="og:description" content="A tic-tac-toe game written in 16-bit x86 assembly for DOS, drawing its own board in VGA graphics mode." />'
    assert_includes body, '<meta property="og:type" content="article" />'
  end

  def test_each_translated_page_declares_its_sibling_locale
    assert_includes page_body("index.html"),
      '<link rel="alternate" hreflang="pt" href="/pt/" />'
    assert_includes page_body("pt/index.html"),
      '<link rel="alternate" hreflang="en" href="/" />'

    assert_includes page_body("projects/tic-tac-toe/index.html"),
      '<link rel="alternate" hreflang="pt" href="/pt/projects/tic-tac-toe/" />'
  end

  # all_locales inclui o proprio recurso; o alternate e so o irmao.
  def test_alternate_never_points_back_at_the_pages_own_locale
    refute_includes page_body("index.html"), 'hreflang="en"'
    refute_includes page_body("pt/index.html"), 'hreflang="pt"'
  end

  def test_og_locale_uses_the_open_graph_territory_form
    assert_includes page_body("index.html"), '<meta property="og:locale" content="en_US" />'
    assert_includes page_body("pt/index.html"), '<meta property="og:locale" content="pt_BR" />'
  end

  # `url` em config/initializers.rb ainda e "" porque o dominio nao foi
  # registrado. Enquanto for, canonical e og:url tem que sair como caminho
  # relativo (valido, e resolvido contra a propria pagina) e nunca como
  # "https:///projects/" ou "/projects/" colado num host vazio.
  def test_urls_degrade_to_relative_paths_while_the_domain_is_unset
    skip "url ja configurado" unless site_url.empty?

    html_pages.each do |path|
      body = File.read(path)
      canonical = body[%r{<link rel="canonical" href="([^"]*)" />}, 1]
      og_url = body[/<meta property="og:url" content="([^"]*)" \/>/, 1]

      assert_match %r{\A/}, canonical.to_s, "#{path}: canonical nao e um caminho absoluto do site"
      assert_equal canonical, og_url, "#{path}: og:url e canonical divergem"
      refute_includes canonical.to_s, "://", "#{path}: canonical com host vazio: #{canonical}"
    end
  end

  def test_error_pages_are_not_indexable
    assert_includes page_body("404.html"), '<meta name="robots" content="noindex" />'
    assert_includes page_body("500.html"), '<meta name="robots" content="noindex" />'
    refute_includes page_body("index.html"), 'name="robots"'
  end

  private

  def site_url
    ROOT.join("config/initializers.rb").read[/^\s*url\s+"([^"]*)"/, 1].to_s
  end
end
