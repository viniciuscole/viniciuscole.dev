require "test_helper"
require "cgi"
require "json"

class RoutesPartialTest < Minitest::Test
  include OutputHelpers

  EN = "projects/car-routes/index.html".freeze
  PT = "pt/projects/car-routes/index.html".freeze

  def test_the_project_page_renders_the_routes_demo
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      assert_includes corpo, 'class="demo demo-routes"', "#{pagina} nao renderizou a demo routes"
      refute_includes corpo, 'class="demo demo-none"'
    end
  end

  def test_the_hooks_the_player_depends_on_exist
    corpo = page_body(EN)
    %w[data-rotas="engarrafamento" data-rotas-editor data-rotas-base="/demos/car-routes"
       data-rotas-textos data-rotas-canvas data-rotas-controles data-rotas-painel data-rotas-erro].each do |gancho|
      assert_includes corpo, gancho, "faltou o gancho #{gancho}"
    end
  end

  def test_the_texts_are_valid_json_in_both_locales
    require "json"
    [EN, PT].each do |pagina|
      bruto = page_body(pagina)[/data-rotas-textos="([^"]+)"/, 1]
      refute_nil bruto, "#{pagina} sem data-rotas-textos"
      textos = JSON.parse(CGI.unescapeHTML(bruto))
      %w[play pause step speed restart clock queue km apply run reset remove instant kmh].each do |chave|
        assert textos.key?(chave), "#{pagina}: falta o texto #{chave}"
      end
    end
  end
end
