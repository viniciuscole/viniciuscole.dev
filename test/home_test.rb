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
end
