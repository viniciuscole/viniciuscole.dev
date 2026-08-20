require "test_helper"

# A home segue o formato de cartao: foto, nome, cargo, apresentacao e links
# diretos ocupam a primeira tela; os destaques vem logo abaixo. O que estes
# testes protegem e a segunda metade — sem eles, a home poderia virar um cartao
# puro numa edicao futura e o visitante nunca descobriria que ha um jogo em
# assembly jogavel dentro do site.
class HomeCardTest < Minitest::Test
  include OutputHelpers

  EN = "index.html".freeze
  PT = "pt/index.html".freeze

  def test_the_card_renders_in_both_locales
    [EN, PT].each do |pagina|
      assert_includes page_body(pagina), 'class="card"',
        "#{pagina} nao renderizou o cartao"
    end
  end

  def test_the_portrait_is_present_with_a_translated_alt
    assert_match(/<img[^>]+class="card-photo"[^>]+alt="[^"]+"/, page_body(EN))

    en = page_body(EN)[/<img[^>]+class="card-photo"[^>]+alt="([^"]+)"/, 1]
    pt = page_body(PT)[/<img[^>]+class="card-photo"[^>]+alt="([^"]+)"/, 1]

    refute_nil en
    refute_nil pt
    refute_equal en, pt, "o alt da foto deveria mudar com o idioma"
  end

  def test_the_role_line_is_translated
    assert_includes page_body(EN), "Software developer"
    assert_includes page_body(PT), "Desenvolvedor de software"
  end

  def test_the_three_contact_links_are_on_the_card
    corpo = page_body(EN)
    cartao = corpo[/<section class="card".*?<\/section>/m]

    refute_nil cartao, "cartao nao encontrado"
    assert_includes cartao, "https://github.com/viniciuscole"
    assert_includes cartao, "linkedin.com"
    assert_includes cartao, "mailto:"
  end

  # Esta e a diferenca entre o nosso site e um agregador de links.
  def test_the_home_still_surfaces_the_projects_and_the_blog
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      assert_includes corpo, 'class="featured"',
        "#{pagina} perdeu a secao de projetos em destaque"
      assert_includes corpo, 'class="latest-posts"',
        "#{pagina} perdeu a secao de posts recentes"
    end
  end

  def test_the_featured_project_is_actually_listed
    assert_includes page_body(EN), "Tic-Tac-Toe in x86 Assembly"
    assert_includes page_body(PT), "Jogo da Velha em Assembly x86"
  end

  def test_the_portrait_file_is_published
    caminho = page_body(EN)[/<img[^>]+class="card-photo"[^>]+src="([^"]+)"/, 1]
    refute_nil caminho, "a foto nao tem src"
    assert output(caminho.sub(%r{\A/}, "")).file?,
      "o arquivo da foto (#{caminho}) nao foi publicado"
  end
end
