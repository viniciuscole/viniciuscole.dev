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

  # Ruling 1: 404.html/500.html nao tem front matter `locale`. Antes do
  # fallback em locale_home_url/locale_prefix, resource.data.locale era nil
  # nessas paginas, produzindo <html lang=""> e um link de alternador de
  # idioma para "//" (link quebrado que o html-proofer da Task 9 rejeitaria).
  def test_404_page_renders_with_a_real_language_and_no_broken_link
    body = page_body("404.html")
    assert_includes body, '<html lang="en">'
    refute_includes body, 'href="//"'
  end
end
