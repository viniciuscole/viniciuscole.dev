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

  def test_portuguese_blog_lists_the_portuguese_post
    body = page_body("pt/blog/index.html")
    assert_includes body, "Portando assembly de DOS para o navegador"
    refute_includes body, "Porting DOS assembly to the browser"
  end

  # As duas traducoes sao arquivos distintos com o mesmo `slug` no front
  # matter. Se o permalink deixasse de prefixar o locale, en e pt gravariam
  # no mesmo caminho e uma sobrescreveria a outra em silencio -- o build
  # continuaria passando com um dos idiomas simplesmente ausente.
  def test_each_locale_gets_its_own_post_page
    assert_page "2026/08/16/porting-dos-assembly-to-the-browser/index.html"
    assert_page "pt/2026/08/16/porting-dos-assembly-to-the-browser/index.html"

    assert_includes page_body("2026/08/16/porting-dos-assembly-to-the-browser/index.html"),
      "Porting DOS assembly to the browser"
    assert_includes page_body("pt/2026/08/16/porting-dos-assembly-to-the-browser/index.html"),
      "Portando assembly de DOS para o navegador"
  end

  # O seletor de idioma acha a traducao por `resource.all_locales`, que pareia
  # os recursos pelo `slug` do front matter. Sem o `slug` compartilhado ele cai
  # para a home do outro idioma em vez de ir para o post correspondente.
  def test_locale_switcher_links_each_post_to_its_translation
    en = page_body("2026/08/16/porting-dos-assembly-to-the-browser/index.html")
    pt = page_body("pt/2026/08/16/porting-dos-assembly-to-the-browser/index.html")

    assert_includes en, 'href="/pt/2026/08/16/porting-dos-assembly-to-the-browser/"'
    assert_includes pt, 'href="/2026/08/16/porting-dos-assembly-to-the-browser/"'
  end

  def test_post_page_has_semantic_structure
    # Task 8 (estilo) escreve CSS mirando `.post time` e `.post-body`; sem
    # esses elementos no markup essas regras nao teriam alvo.
    body = page_body("2026/08/16/porting-dos-assembly-to-the-browser/index.html")
    assert_includes body, '<article class="post">'
    assert_includes body, '<time datetime="2026-08-16">'
    assert_includes body, '<div class="post-body">'
  end
end
