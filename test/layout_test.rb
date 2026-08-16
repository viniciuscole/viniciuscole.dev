require "test_helper"
require "bridgetown"
require "tmpdir"
require "fileutils"

class LayoutTest < Minitest::Test
  include OutputHelpers

  # Instancia real de Bridgetown::TemplateView::Helpers, ligada a um
  # Bridgetown::Site construido a partir da configuracao real do projeto
  # (config/initializers.rb, locales, etc). Usada para chamar
  # locale_home_url/locale_prefix diretamente, do mesmo jeito que os
  # templates fazem via `helper`, sem depender de nenhuma pagina do site ter
  # (ou deixar de ter) `locale` no front matter. E o unico jeito honesto de
  # provar o fallback: se `Builders::SiteHelpers` nao caisse para o idioma
  # padrao quando `locale` e nil/vazio, essas chamadas devolveriam "//" e
  # "/" em vez de "/" e "".
  def self.locale_helpers
    @locale_helpers ||= begin
      destination = Dir.mktmpdir("layout_test_output")
      at_exit { FileUtils.remove_entry(destination) if File.exist?(destination) }
      config = Bridgetown.configuration(
        "root_dir"    => ROOT.to_s,
        "source"      => ROOT.join("src").to_s,
        "destination" => destination,
        "quiet"       => true,
        "environment" => "test"
      )
      site = Bridgetown::Site.new(config)
      site.read # dispara o hook :pre_read, que roda os builders e registra os helpers
      Bridgetown::TemplateView::Helpers.new(nil, site)
    end
  end

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

  # Ruling 1: 404.html/500.html nao tem front matter `locale`. Antes do
  # fallback em locale_home_url/locale_prefix, resource.data.locale era nil
  # nessas paginas, produzindo <html lang=""> e um link de alternador de
  # idioma para "//" (link quebrado que o html-proofer da Task 9 rejeitaria).
  #
  # Este teste prova que a pagina renderizada esta correta (front matter
  # `locale: en` + a home em portugues nao existe para 404.html, entao o
  # switcher cai no fallback de contraparte ausente). Ele NAO exercita o
  # fallback de locale nil/vazio dentro dos helpers — isso e coberto
  # separadamente pelos testes abaixo, que chamam os helpers diretamente.
  def test_404_page_renders_with_a_real_language_and_no_broken_link
    body = page_body("404.html")
    assert_includes body, '<html lang="en">'

    switcher = body[/<nav class="locale-switcher".*?<\/nav>/m]
    refute_nil switcher, "alternador de idioma nao encontrado na pagina 404"
    assert_includes switcher, 'href="/pt/"'

    refute_includes body, 'href="//"'
  end

  # Prova direta do fallback do Ruling 1: chama os helpers do jeito que os
  # templates chamam (via Bridgetown::TemplateView::Helpers), passando nil e
  # "" como `locale` — exatamente o que resource.data.locale seria numa
  # pagina que esquecesse o front matter `locale`. Sem a linha
  # `locale = site.config.default_locale if locale.to_s.empty?` em
  # plugins/builders/site_helpers.rb, estas chamadas devolveriam "//" e "/"
  # em vez de "/" e "".
  def test_locale_home_url_falls_back_to_the_default_locale_when_locale_is_missing
    helpers = self.class.locale_helpers

    assert_equal "/", helpers.locale_home_url(nil)
    assert_equal "/", helpers.locale_home_url("")
  end

  def test_locale_prefix_falls_back_to_the_default_locale_when_locale_is_missing
    helpers = self.class.locale_helpers

    assert_equal "", helpers.locale_prefix(nil)
    assert_equal "", helpers.locale_prefix("")
  end
end
