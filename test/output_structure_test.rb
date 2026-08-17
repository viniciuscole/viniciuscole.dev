require "test_helper"

class OutputStructureTest < Minitest::Test
  include OutputHelpers

  def test_home_is_generated
    assert_page "index.html"
  end

  # Seis das onze paginas ja imprimiram o proprio titulo duas vezes: o layout
  # `page` emitia <h1><%= data.title %></h1> e o corpo da pagina emitia o seu
  # a partir de uma chave t(). Alem do duplicado visivel, um documento com
  # dois <h1> quebra o esquema de cabecalhos para leitor de tela.
  def test_every_page_has_exactly_one_h1
    html_pages.each do |path|
      headings = File.read(path).scan(/<h1[\s>]/).size
      assert_equal 1, headings,
        "#{path}: esperava exatamente um <h1>, encontrei #{headings}"
    end
  end
end
