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
