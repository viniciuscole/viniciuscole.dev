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

  def test_pt_home_features_the_flagged_project
    assert_includes page_body("pt/index.html"), "Jogo da Velha em Assembly x86"
  end

  def test_home_does_not_leak_the_other_locale
    refute_includes page_body("index.html"), "Jogo da Velha"
    refute_includes page_body("pt/index.html"), "Tic-Tac-Toe in x86"
  end

  def test_project_card_links_to_the_project_page
    assert_includes page_body("projects/index.html"), 'href="/projects/tic-tac-toe/"'
  end

  # A spec pede "Home com apresentacao, projetos em destaque, posts recentes e
  # links de contato". A secao de posts recentes tinha sido esquecida, e as
  # chaves home.latest_posts ficaram nos dois locales sem referencia nenhuma —
  # o teste de paridade nao ve chave morta, porque ela esta morta nos dois.
  def test_home_lists_the_recent_posts
    body = page_body("index.html")

    assert_includes body, "Latest posts"
    assert_includes body, "Porting DOS assembly to the browser"
  end

  def test_pt_home_lists_the_recent_posts_with_its_own_empty_state
    body = page_body("pt/index.html")

    assert_includes body, "Últimos posts"
    # o unico post existe so em ingles; a home em portugues mostra o vazio
    assert_includes body, "Nenhum post por aqui ainda"
    refute_includes body, "Porting DOS assembly to the browser"
  end

  # Contato e servido pelo footer, em toda pagina. Se voltar uma chave
  # home.contact sem uso, ela e chave morta de novo.
  def test_home_reaches_the_contact_links_through_the_footer
    assert_includes page_body("index.html"), '<footer class="site-footer">'
  end
end
